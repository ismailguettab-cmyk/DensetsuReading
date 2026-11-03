import 'package:flutter/material.dart';

import '../anilist/anilist.dart';
import '../core/activity.dart';
import '../core/l10n.dart';
import '../core/motion.dart';
import '../core/net.dart';
import '../core/services.dart';
import '../core/theme.dart';
import '../sources/catalog.dart';
import 'manga_page.dart';
import 'shell.dart';
import 'widgets.dart';

/// Profile: counts, what was read recently, what's next on the reading plan.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = Services.i;
    return Scaffold(
      body: ListenableBuilder(
        listenable: Listenable.merge([s.session, s.activity]),
        builder: (context, _) {
          final session = s.session;
          final user = session.user;
          if (user == null) {
            return Center(
              child: session.error != null
                  ? EmptyState(
                      icon: Icons.cloud_off_rounded,
                      title: context.t('login.error'),
                      action: AppButton(label: context.t('detail.retry'), tone: ButtonTone.quiet, onTap: session.refresh),
                    )
                  : const CircularProgressIndicator(strokeWidth: 2),
            );
          }
          final read = session.withStatus({'COMPLETED', 'REPEATING'});
          final reading = session.withStatus({'CURRENT'});
          final planning = session.withStatus({'PLANNING'});
          final recent = session.withStatus({'CURRENT', 'COMPLETED', 'REPEATING', 'PAUSED'}).take(5).toList();
          final resume = s.activity.reads.isEmpty ? null : s.activity.reads.first;
          final pad = pagePadding(context);

          return RefreshIndicator(
            onRefresh: session.refresh,
            color: context.pal.accent,
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _Hero(user: user),
                Padding(
                  padding: EdgeInsets.fromLTRB(pad.left, 0, pad.right, pad.bottom),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Reveal(
                      index: 2,
                      child: _Stats(items: [
                        (context.t('home.read'), read.length, Icons.done_all_rounded),
                        (context.t('home.reading'), reading.length, Icons.auto_stories_rounded),
                        (context.t('home.planning'), planning.length, Icons.bookmark_rounded),
                        (context.t('home.chapters'), user.chaptersRead, Icons.layers_rounded),
                      ]),
                    ),
                    if (resume != null) ...[
                      const SizedBox(height: 40),
                      Reveal(index: 3, child: SectionTitle(context.t('home.continue'))),
                      Reveal(index: 4, child: _ResumeCard(event: resume)),
                    ],
                    const SizedBox(height: 40),
                    Reveal(index: 4, child: SectionTitle(context.t('home.recent'))),
                    if (recent.isEmpty)
                      Text(context.t('home.empty'), style: Txt.body(context))
                    else
                      Reveal(index: 5, child: _RecentList(entries: recent)),
                    if (planning.isNotEmpty) ...[
                      const SizedBox(height: 40),
                      Reveal(index: 6, child: SectionTitle(context.t('home.plan'))),
                      Reveal(index: 7, child: _CoverRow(entries: planning.take(14).toList())),
                    ],
                  ]),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.user});
  final AniUser user;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final pad = pagePadding(context);
    final hour = DateTime.now().hour;
    final hello = context.t(hour >= 18 || hour < 5 ? 'home.evening' : 'home.hello');
    return SizedBox(
      height: 270,
      child: Stack(fit: StackFit.expand, children: [
        if (user.banner != null)
          Opacity(
            opacity: 0.55,
            child: Image.network(Net.image(user.banner!), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox()),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [p.bg.withValues(alpha: user.banner == null ? 0 : 0.2), p.bg],
            ),
          ),
        ),
        Positioned(
          left: pad.left,
          right: pad.right,
          bottom: 34,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Reveal(
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(color: p.bg, shape: BoxShape.circle),
                child: CircleAvatar(
                  radius: 38,
                  backgroundColor: p.surface2,
                  backgroundImage: user.avatar == null ? null : NetworkImage(Net.image(user.avatar!)),
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Reveal(
                index: 1,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('$hello, ${user.name}', maxLines: 1, overflow: TextOverflow.ellipsis, style: Txt.display(context)),
                  const SizedBox(height: 6),
                  Text(context.t('home.subtitle'), style: Txt.body(context).copyWith(fontSize: 15)),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.items});
  final List<(String, int, IconData)> items;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return LayoutBuilder(builder: (context, box) {
      final columns = box.maxWidth >= 720 ? 4 : 2;
      final gap = 14.0;
      final w = (box.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(spacing: gap, runSpacing: gap, children: [
        for (final (label, value, icon) in items)
          Container(
            width: w,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: p.line)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, size: 19, color: p.accent),
              const SizedBox(height: 18),
              CountUp(value: value, style: Txt.number(context, size: 32)),
              const SizedBox(height: 6),
              Text(label, style: Txt.caption(context).copyWith(fontSize: 13)),
            ]),
          ),
      ]);
    });
  }
}

class _RecentList extends StatelessWidget {
  const _RecentList({required this.entries});
  final List<AniEntry> entries;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: p.line)),
      child: Column(children: [
        for (var i = 0; i < entries.length; i++) ...[
          if (i > 0) Divider(height: 1, color: p.line, indent: 92),
          Pressable(
            scale: 0.99,
            onTap: () => Navigator.of(context).push(SoftRoute(MangaPage.anilist(entries[i].media, heroTag: 'recent-${entries[i].media.id}'))),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(children: [
                SizedBox(
                  width: 56,
                  height: 80,
                  child: CoverImage(url: entries[i].media.cover, radius: 9, heroTag: 'recent-${entries[i].media.id}'),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(entries[i].media.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Txt.title(context)),
                    const SizedBox(height: 5),
                    Text(
                      [
                        if (entries[i].progress > 0) '${context.t('home.chapter')} ${entries[i].progress}',
                        ...entries[i].media.genres.take(2),
                      ].join('  ·  '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Txt.caption(context),
                    ),
                  ]),
                ),
                const SizedBox(width: 12),
                Text(context.ago(entries[i].updated), style: Txt.caption(context).copyWith(color: p.text2)),
                const SizedBox(width: 6),
                Icon(Icons.chevron_right_rounded, color: p.text3),
              ]),
            ),
          ),
        ],
      ]),
    );
  }
}

class _ResumeCard extends StatelessWidget {
  const _ResumeCard({required this.event});
  final ReadEvent event;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final source = sourceById(event.sourceId);
    return Pressable(
      scale: 0.985,
      onTap: source == null
          ? null
          : () => Navigator.of(context).push(SoftRoute(MangaPage.resume(event))),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: p.line)),
        child: Row(children: [
          SizedBox(
            width: 64,
            height: 92,
            child: CoverImage(url: event.cover, headers: source?.imageHeaders ?? const {}, radius: 10),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(event.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Txt.title(context).copyWith(fontSize: 16)),
              const SizedBox(height: 6),
              Text(
                '${event.chapterName}  ·  ${source?.name ?? ''}  ·  ${context.ago(event.at)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Txt.caption(context),
              ),
            ]),
          ),
          const SizedBox(width: 12),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: p.cta, shape: BoxShape.circle),
            child: Icon(Icons.play_arrow_rounded, color: p.onCta),
          ),
        ]),
      ),
    );
  }
}

class _CoverRow extends StatelessWidget {
  const _CoverRow({required this.entries});
  final List<AniEntry> entries;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 262,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: entries.length,
        separatorBuilder: (_, __) => const SizedBox(width: 18),
        itemBuilder: (context, i) {
          final m = entries[i].media;
          return MangaCard(
            title: m.title,
            cover: m.cover,
            subtitle: m.genres.take(2).join(' · '),
            heroTag: 'plan-${m.id}',
            onTap: () => Navigator.of(context).push(SoftRoute(MangaPage.anilist(m, heroTag: 'plan-${m.id}'))),
          );
        },
      ),
    );
  }
}
