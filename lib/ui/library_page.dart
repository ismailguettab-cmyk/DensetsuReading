import 'package:flutter/material.dart';

import '../anilist/anilist.dart';
import '../core/l10n.dart';
import '../core/motion.dart';
import '../core/services.dart';
import '../core/theme.dart';
import 'manga_page.dart';
import 'shell.dart';
import 'widgets.dart';

enum LibraryShelf {
  read({'COMPLETED', 'REPEATING'}, 'home.read'),
  reading({'CURRENT'}, 'home.reading'),
  planning({'PLANNING'}, 'home.planning');

  const LibraryShelf(this.statuses, this.label);
  final Set<String> statuses;
  final String label;
}

/// The user's AniList shelves: read, reading, plan to read.
class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key, required this.initial});
  final LibraryShelf initial;

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  late LibraryShelf _shelf = widget.initial;
  String _sort = 'recent';

  List<AniEntry> _sorted(List<AniEntry> entries) {
    final list = [...entries];
    switch (_sort) {
      case 'alpha':
        list.sort((a, b) => a.media.title.toLowerCase().compareTo(b.media.title.toLowerCase()));
      case 'score':
        // The user's own score first, the community score to break ties and for unrated titles.
        list.sort((a, b) {
          final s = b.score.compareTo(a.score);
          return s != 0 ? s : (b.media.meanScore ?? 0).compareTo(a.media.meanScore ?? 0);
        });
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final pad = pagePadding(context);
    return Scaffold(
      body: ListenableBuilder(
        listenable: Services.i.session,
        builder: (context, _) {
          final entries = _sorted(Services.i.session.withStatus(_shelf.statuses));
          return CustomScrollView(slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(pad.left, pad.top - 8, pad.right, 26),
              sliver: SliverToBoxAdapter(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  IconCircle(icon: Icons.arrow_back_rounded, onTap: () => Navigator.of(context).maybePop(), tooltip: context.t('common.back')),
                  const SizedBox(height: 24),
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: Motion.fast,
                        layoutBuilder: (current, previous) =>
                            Stack(alignment: Alignment.centerLeft, children: [...previous, ?current]),
                        child: Text(context.t(_shelf.label), key: ValueKey(_shelf), style: Txt.display(context)),
                      ),
                    ),
                    Text('${entries.length}', style: Txt.number(context, size: 22).copyWith(color: p.text3)),
                  ]),
                  const SizedBox(height: 20),
                  Wrap(spacing: 14, runSpacing: 12, children: [
                    SizedBox(
                      width: 460,
                      child: Segmented<LibraryShelf>(
                        value: _shelf,
                        options: [for (final s in LibraryShelf.values) (s, context.t(s.label))],
                        onChanged: (v) => setState(() => _shelf = v),
                      ),
                    ),
                    SizedBox(
                      width: 300,
                      child: Segmented<String>(
                        value: _sort,
                        options: [
                          ('recent', context.isEn ? 'Recent' : 'Récents'),
                          ('alpha', 'A → Z'),
                          ('score', context.isEn ? 'Score' : 'Note'),
                        ],
                        onChanged: (v) => setState(() => _sort = v),
                      ),
                    ),
                  ]),
                ]),
              ),
            ),
            if (entries.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(icon: Icons.menu_book_rounded, title: context.isEn ? 'Nothing here yet' : 'Rien ici pour l’instant'),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(pad.left, 0, pad.right, pad.bottom),
                sliver: SliverGrid.builder(
                  key: ValueKey('$_shelf-$_sort'),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 172,
                    mainAxisSpacing: 28,
                    crossAxisSpacing: 20,
                    childAspectRatio: 0.5,
                  ),
                  itemCount: entries.length,
                  itemBuilder: (context, i) => Reveal(index: i % 18, step: 30, offset: 16, child: _EntryCard(entry: entries[i])),
                ),
              ),
          ]);
        },
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry});
  final AniEntry entry;

  @override
  Widget build(BuildContext context) {
    final m = entry.media;
    final tag = 'library-${m.id}';
    final progress = entry.progress > 0
        ? '${context.t('home.chapter')} ${entry.progress}${m.chapters != null ? ' / ${m.chapters}' : ''}'
        : null;
    return Tilt(
      maxAngle: 0.1,
      child: MangaCard(
        width: double.infinity,
        title: m.title,
        cover: m.cover,
        heroTag: tag,
        subtitle: [?progress, if (entry.score > 0) '★ ${(entry.score / 10).toStringAsFixed(1)}'].join('  ·  '),
        onTap: () => Navigator.of(context).push(SoftRoute(MangaPage.anilist(m, heroTag: tag))),
      ),
    );
  }
}
