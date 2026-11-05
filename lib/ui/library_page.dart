import 'dart:math';

import 'package:flutter/material.dart';

import '../anilist/anilist.dart';
import '../core/l10n.dart';
import '../core/motion.dart';
import '../core/services.dart';
import '../core/theme.dart';
import 'ink.dart';
import 'manga_page.dart';
import 'widgets.dart';

enum LibraryShelf {
  read({'COMPLETED', 'REPEATING'}, 'home.read'),
  reading({'CURRENT'}, 'home.reading'),
  planning({'PLANNING'}, 'home.planning');

  const LibraryShelf(this.statuses, this.label);
  final Set<String> statuses;
  final String label;
}

/// The user's AniList shelves (read, reading, plan to read), opened from home under an ink sweep.
class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key, required this.initial});
  final LibraryShelf initial;

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  late LibraryShelf _shelf = widget.initial;
  String _sort = 'recent';
  bool _opened = false; // first grid waits for the ink to clear, later ones play at once

  List<AniEntry> _sorted(List<AniEntry> entries) {
    final list = [...entries];
    switch (_sort) {
      case 'alpha':
        list.sort((a, b) => a.media.title.toLowerCase().compareTo(b.media.title.toLowerCase()));
      case 'score':
        // The user's own score first, the community score for ties and unrated titles.
        list.sort((a, b) {
          final s = b.score.compareTo(a.score);
          return s != 0 ? s : (b.media.meanScore ?? 0).compareTo(a.media.meanScore ?? 0);
        });
    }
    return list;
  }

  void _set(VoidCallback change) => setState(() {
        change();
        _opened = true;
      });

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Scaffold(
      body: ListenableBuilder(
        listenable: Services.i.session,
        builder: (context, _) {
          final entries = _sorted(Services.i.session.withStatus(_shelf.statuses));
          final wide = MediaQuery.sizeOf(context).width >= 900;
          final pad = wide ? 48.0 : 22.0;
          final base = _opened ? 50 : 450;
          return CustomScrollView(slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(pad, 28, pad, 20),
              sliver: SliverToBoxAdapter(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                    Pressable(
                      onTap: () => Navigator.of(context).maybePop(),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: inkBlack, width: 2)),
                        child: const Icon(Icons.arrow_back_rounded, color: inkBlack, size: 22),
                      ),
                    ),
                    const SizedBox(width: 18),
                    Flexible(child: Text(context.t(_shelf.label), style: Txt.display(context), overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 18),
                    Text('${entries.length} mangas', style: Txt.label(context).copyWith(fontSize: 15, color: p.text3)),
                  ]),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.only(bottom: 6),
                    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: inkBlack, width: 2))),
                    child: Wrap(
                      spacing: 24,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        Wrap(spacing: 26, children: [
                          for (final s in LibraryShelf.values) _ShelfTab(label: context.t(s.label), active: s == _shelf, onTap: () => _set(() => _shelf = s)),
                        ]),
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(context.isEn ? 'Sort by' : 'Trier par', style: Txt.body(context).copyWith(fontSize: 14, color: p.text3)),
                          const SizedBox(width: 10),
                          for (final (k, fr, en) in const [('recent', 'Récents', 'Recent'), ('alpha', 'Titre', 'Title'), ('score', 'Note', 'Score')])
                            _SortButton(label: context.isEn ? en : fr, active: _sort == k, onTap: () => _set(() => _sort = k)),
                        ]),
                      ],
                    ),
                  ),
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
                padding: EdgeInsets.fromLTRB(pad, 0, pad, wide ? 30 : 120),
                sliver: SliverGrid.builder(
                  key: ValueKey('$_shelf-$_sort'),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 160,
                    mainAxisSpacing: 22,
                    crossAxisSpacing: 20,
                    childAspectRatio: 0.5,
                  ),
                  itemCount: entries.length,
                  itemBuilder: (context, i) => _Item(entry: entries[i], shelf: _shelf, delay: Duration(milliseconds: base + 35 * min(i, 24))),
                ),
              ),
          ]);
        },
      ),
    );
  }
}

class _ShelfTab extends StatelessWidget {
  const _ShelfTab({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: SizedBox(
        height: 44,
        child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
          if (active) const Positioned(left: -4, right: -4, bottom: 4, child: InkUnderline()),
          Text(label, style: Txt.label(context).copyWith(fontSize: 16, fontWeight: active ? FontWeight.w900 : FontWeight.w500)),
        ]),
      ),
    );
  }
}

class _SortButton extends StatelessWidget {
  const _SortButton({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(-2, 0),
      child: Pressable(
        onTap: onTap,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: active ? inkBlack : Colors.transparent, border: Border.all(color: inkBlack, width: 2)),
          child: Text(label, style: Txt.label(context).copyWith(color: active ? inkPaper : inkBlack)),
        ),
      ),
    );
  }
}

/// A cover with hand-cut edges that swings into place like a page turning toward you.
class _Item extends StatelessWidget {
  const _Item({required this.entry, required this.shelf, required this.delay});
  final AniEntry entry;
  final LibraryShelf shelf;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    final m = entry.media;
    final score = m.meanScore != null ? '★ ${(m.meanScore! / 10).toStringAsFixed(1).replaceAll('.', ',')}' : null;
    final sub = shelf == LibraryShelf.planning
        ? (score ?? '')
        : [if (entry.progress > 0) '${context.t('home.chapter')} ${entry.progress}${m.chapters != null ? ' / ${m.chapters}' : ''}', ?score].join(' · ');
    final tag = 'library-${m.id}';
    return Pressable(
      onTap: () => Navigator.of(context).push(SoftRoute(MangaPage.anilist(m, heroTag: tag))),
      child: OneShot(
        delay: delay,
        duration: const Duration(milliseconds: 450),
        builder: (context, t, child) {
          final e = const Cubic(0.2, 0.9, 0.3, 1).transform(t);
          return Opacity(
            opacity: 0.5 + 0.5 * t,
            child: Transform(
              alignment: Alignment.centerLeft,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 1 / 800)
                ..rotateY((1 - e) * -84 * pi / 180),
              child: child,
            ),
          );
        },
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AspectRatio(
            aspectRatio: 2 / 3,
            child: Stack(clipBehavior: Clip.none, children: [
              Positioned.fill(child: ClipPath(clipper: const CutClipper(), child: CoverImage(url: m.cover, radius: 0, heroTag: tag, title: m.title))),
              if (shelf == LibraryShelf.read) const Positioned(right: -6, bottom: -4, child: HankoStamp(size: 38)),
              if (shelf == LibraryShelf.reading) const Positioned(right: 12, top: -8, width: 16, height: 48, child: BrushShape(Brush.ribbon, color: inkRed)),
            ]),
          ),
          const SizedBox(height: 6),
          Text(m.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Txt.label(context)),
          if (shelf == LibraryShelf.reading && m.chapters != null && m.chapters! > 0) ...[
            const SizedBox(height: 4),
            SizedBox(
              height: 4,
              child: Stack(children: [
                const Positioned.fill(child: ColoredBox(color: Color(0x26121010))),
                FractionallySizedBox(widthFactor: (entry.progress / m.chapters!).clamp(0.0, 1.0), child: const ColoredBox(color: inkBlack)),
              ]),
            ),
          ],
          if (sub.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: Txt.caption(context).copyWith(fontSize: 12)),
          ],
        ]),
      ),
    );
  }
}

