import 'dart:math';

import 'package:flutter/material.dart';

import '../anilist/anilist.dart';
import '../core/activity.dart';
import '../core/l10n.dart';
import '../core/motion.dart';
import '../core/net.dart';
import '../core/services.dart';
import '../core/theme.dart';
import '../sources/catalog.dart';
import 'ink.dart';
import 'library_page.dart';
import 'manga_page.dart';
import 'widgets.dart';

/// Home (day mode): greeting, the manga to resume painted in with brush strokes,
/// the main character inked on a red sun, then the three shelves of the library.
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
                  : const CircularProgressIndicator(strokeWidth: 2, color: inkBlack),
            );
          }
          final resume = _Resume.pick(context, s.activity.reads.firstOrNull, session.withStatus({'CURRENT'}).firstOrNull);
          return LayoutBuilder(builder: (context, box) {
            final wide = box.maxWidth >= 900;
            final pad = wide ? 48.0 : 22.0;
            return RefreshIndicator(
              onRefresh: session.refresh,
              color: inkRed,
              child: ListView(padding: EdgeInsets.only(bottom: wide ? 36 : 120), children: [
                _Header(user: user, resume: resume, wide: wide, pad: pad),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: pad),
                  child: const SizedBox(height: 18, child: BrushShape(Brush.divider)),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(pad, 18, pad, 0),
                  child: _Shelves(wide: wide),
                ),
                _RecentReads(pad: pad),
              ]),
            );
          });
        },
      ),
    );
  }
}

/// What "Reprendre" points at: the last chapter opened in the app, else the first manga in progress on AniList.
class _Resume {
  _Resume({required this.title, required this.cover, required this.headers, required this.sub, required this.line, this.page, this.total, this.anilistId, required this.open});

  final String title;
  final String? cover;
  final Map<String, String> headers;
  final String sub, line;
  final int? page, total, anilistId;
  final void Function(BuildContext) open;

  static _Resume? pick(BuildContext context, ReadEvent? read, AniEntry? reading) {
    if (read != null) {
      final source = sourceById(read.sourceId);
      return _Resume(
        title: read.title,
        cover: read.cover,
        headers: source?.imageHeaders ?? const {},
        sub: '${context.isEn ? 'Read' : 'Lu'} ${context.ago(read.at)}${source != null ? ' · ${source.name}' : ''}',
        line: '${read.chapterName} · ${context.t('reader.page').toLowerCase()} ${read.page + 1}${read.total != null ? ' / ${read.total}' : ''}',
        page: read.page + 1,
        total: read.total,
        anilistId: read.anilistId,
        open: (context) => Navigator.of(context).push(SoftRoute(MangaPage.resume(read))),
      );
    }
    if (reading != null) {
      final m = reading.media;
      return _Resume(
        title: m.title,
        cover: m.cover,
        headers: const {},
        sub: '${context.isEn ? 'Updated' : 'Mis à jour'} ${context.ago(reading.updated)} · AniList',
        line: '${context.t('home.chapter')} ${reading.progress}${m.chapters != null ? ' / ${m.chapters}' : ''}',
        page: reading.progress,
        total: m.chapters,
        anilistId: m.id,
        open: (context) => Navigator.of(context).push(SoftRoute(MangaPage.anilist(m))),
      );
    }
    return null;
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.user, required this.resume, required this.wide, required this.pad});
  final AniUser user;
  final _Resume? resume;
  final bool wide;
  final double pad;

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final hello = context.t(hour >= 18 || hour < 5 ? 'home.evening' : 'home.hello');
    final greeting = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: inkBlack, width: 2)),
          child: ClipOval(
            child: user.avatar == null ? const ColoredBox(color: Color(0xFFEAE2D1)) : Image.network(Net.image(user.avatar!), fit: BoxFit.cover),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(child: Text(context.isEn ? 'Connected to AniList' : 'Connecté à AniList', style: Txt.label(context).copyWith(fontSize: 13, color: context.pal.text2))),
      ]),
      const SizedBox(height: 12),
      Text('$hello, ${user.name}', style: Txt.display(context).copyWith(fontSize: 46)),
      const SizedBox(height: 10),
      Text(context.t('home.subtitle'), style: Txt.body(context)),
    ]);

    final resumeBlock = resume == null ? const SizedBox.shrink() : _ResumeBlock(resume: resume!, compact: !wide);

    if (!wide) {
      return Padding(
        padding: EdgeInsets.fromLTRB(pad, 28, pad, 22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [greeting, const SizedBox(height: 26), resumeBlock]),
      );
    }
    return SizedBox(
      height: 372,
      child: Stack(clipBehavior: Clip.hardEdge, children: [
        if (resume?.anilistId != null) Positioned(right: 0, top: 0, width: 430, height: 372, child: InkPortrait(mediaId: resume!.anilistId!)),
        Padding(
          padding: EdgeInsets.fromLTRB(pad, 28, pad, 28),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            SizedBox(width: 250, child: greeting),
            const SizedBox(width: 34),
            Flexible(child: resumeBlock),
            const SizedBox(width: 300),
          ]),
        ),
      ]),
    );
  }
}

class _ResumeBlock extends StatelessWidget {
  const _ResumeBlock({required this.resume, required this.compact});
  final _Resume resume;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cover = BrushCover(cover: resume.cover, headers: resume.headers, title: resume.title, width: compact ? 150 : 206);

    final info = OneShot(
      delay: const Duration(milliseconds: 450),
      duration: const Duration(milliseconds: 400),
      builder: (context, t, child) {
        final e = const Cubic(0.2, 0.8, 0.2, 1).transform(t);
        return Opacity(opacity: t, child: Transform.translate(offset: Offset(0, (1 - e) * 18), child: child));
      },
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        InkTag(context.isEn ? 'CONTINUE READING' : 'REPRENDRE LA LECTURE'),
        const SizedBox(height: 10),
        Text(
          resume.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Txt.display(context).copyWith(fontSize: compact ? 34 : 46, height: 0.98),
        ),
        const SizedBox(height: 8),
        Text(resume.sub, style: Txt.body(context).copyWith(fontSize: 14)),
        if (resume.total != null && resume.total! > 0) ...[
          const SizedBox(height: 10),
          _PageTicks(done: resume.page ?? 0, total: resume.total!),
        ],
        const SizedBox(height: 14),
        Pressable(
          onTap: () => resume.open(context),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const EnsoButton(),
            const SizedBox(width: 14),
            Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(context.isEn ? 'Resume' : 'Reprendre', style: Txt.h2(context).copyWith(fontSize: 24, height: 1)),
              const SizedBox(height: 3),
              Text(resume.line, style: Txt.label(context).copyWith(fontSize: 12, color: context.pal.text2)),
            ]),
          ]),
        ),
      ]),
    );

    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Pressable(onTap: () => resume.open(context), child: cover),
      SizedBox(width: compact ? 22 : 30),
      Flexible(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 290), child: info)),
    ]);
  }
}

/// One tick per page (or chapter), filled up to the current one.
class _PageTicks extends StatelessWidget {
  const _PageTicks({required this.done, required this.total});
  final int done, total;

  @override
  Widget build(BuildContext context) {
    final n = min(total, 40);
    final filled = (done / total * n).round();
    return SizedBox(
      width: 220,
      height: 6,
      child: Row(children: [
        for (var i = 0; i < n; i++) ...[
          if (i > 0) const SizedBox(width: 2),
          Expanded(child: ColoredBox(color: i < filled ? inkBlack : const Color(0x2E121010))),
        ],
      ]),
    );
  }
}

class _Shelves extends StatelessWidget {
  const _Shelves({required this.wide});
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final session = Services.i.session;
    final shelves = [
      for (final (i, shelf) in LibraryShelf.values.indexed) _Shelf(shelf: shelf, entries: session.withStatus(shelf.statuses), index: i),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(context.isEn ? 'Your library' : 'Ta bibliothèque', style: Txt.h2(context).copyWith(fontSize: 26)),
      const SizedBox(height: 10),
      if (wide)
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (var i = 0; i < shelves.length; i++) ...[
            if (i > 0) const SizedBox(width: 34),
            Expanded(child: shelves[i]),
          ],
        ])
      else
        Column(children: [for (final s in shelves) Padding(padding: const EdgeInsets.only(bottom: 26), child: s)]),
    ]);
  }
}

/// A shelf: count, label, "see all", then one cover face out and spines beside it.
/// Books drop in once; hovering lifts them; a tap lifts the row and sweeps ink to the library.
class _Shelf extends StatefulWidget {
  const _Shelf({required this.shelf, required this.entries, required this.index});
  final LibraryShelf shelf;
  final List<AniEntry> entries;
  final int index;

  @override
  State<_Shelf> createState() => _ShelfState();
}

class _ShelfState extends State<_Shelf> with SingleTickerProviderStateMixin {
  bool _hover = false;
  late final _lift = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));

  @override
  void dispose() {
    _lift.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    if (_lift.isAnimating) return;
    if (!Motion.reduced(context)) await _lift.forward(from: 0);
    if (!mounted) return;
    await Navigator.of(context).push(InkRoute(LibraryPage(initial: widget.shelf)));
    _lift.value = 0;
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.entries;
    final face = entries.firstOrNull;
    final spines = entries.skip(1).take(6).toList();
    final base = 700 + widget.index * 150;
    const heights = [168.0, 152.0, 172.0, 158.0, 146.0, 166.0];
    const widths = [28.0, 24.0, 30.0, 26.0, 24.0, 28.0];
    const bands = [(inkPaper, inkBlack), (inkBlack, inkPaper), (inkRed, inkPaper)];

    Widget drop(int i, Widget child) => OneShot(
          delay: Duration(milliseconds: base + 50 * i),
          builder: (context, t, c) => Opacity(
            opacity: t.clamp(0.0, 1.0),
            child: Transform.translate(offset: Offset(0, (1 - const Cubic(0.2, 1.2, 0.4, 1).transform(t)) * -30), child: c),
          ),
          child: child,
        );

    final row = Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      if (face != null)
        drop(
          0,
          Padding(
            padding: const EdgeInsets.only(right: 9),
            child: SizedBox(
              width: 112,
              height: 164,
              child: Stack(clipBehavior: Clip.none, children: [
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: inkBlack, width: 2),
                      boxShadow: const [BoxShadow(color: Color(0x59121010), offset: Offset(4, 0))],
                    ),
                    child: CoverImage(url: face.media.cover, radius: 0, title: face.media.title),
                  ),
                ),
                if (widget.shelf == LibraryShelf.reading)
                  const Positioned(right: 14, top: -12, width: 18, height: 56, child: BrushShape(Brush.ribbon, color: inkRed)),
                if (widget.shelf == LibraryShelf.planning)
                  Positioned(left: -6, top: 12, child: InkTag(context.isEn ? 'TO READ' : 'À LIRE', angle: -4 * pi / 180)),
              ]),
            ),
          ),
        ),
      for (var i = 0; i < spines.length; i++)
        Padding(
          padding: const EdgeInsets.only(right: 3),
          child: drop(i + 1, _Spine(entry: spines[i], width: widths[i], height: heights[i], band: bands[i % 3])),
        ),
    ]);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _open,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            RollingNumber(value: entries.length, style: Txt.number(context, size: 34)),
            const SizedBox(width: 10),
            Expanded(child: Text(context.t(widget.shelf.label), style: Txt.label(context).copyWith(fontSize: 15))),
            Text(context.isEn ? 'See all →' : 'Tout voir →', style: Txt.label(context).copyWith(fontSize: 13, color: inkRed)),
          ]),
          const SizedBox(height: 8),
          SizedBox(
            height: 176,
            child: AnimatedBuilder(
              animation: _lift,
              builder: (context, child) {
                // Hover: books rise a little. Tap: the row lifts, tilts, then holds while the ink comes.
                final t = _lift.value;
                final lift = t < 0.4 ? 22 * (t / 0.4) : 22 - 8 * ((t - 0.4) / 0.6);
                final dy = t > 0 ? -lift : (_hover ? -6.0 : 0.0);
                return AnimatedSlide(
                  offset: Offset.zero,
                  duration: Motion.fast,
                  child: Transform.translate(
                    offset: Offset(0, dy),
                    child: Transform.rotate(angle: t > 0 && t < 0.6 ? -2 * pi / 180 * sin(t / 0.6 * pi) : 0, child: child),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: entries.isEmpty
                    ? Align(alignment: Alignment.bottomLeft, child: Text(context.isEn ? 'Empty shelf' : 'Étagère vide', style: Txt.caption(context)))
                    : Align(alignment: Alignment.bottomLeft, child: ClipRect(child: row)),
              ),
            ),
          ),
          const SizedBox(height: 16, child: BrushShape(Brush.plank)),
        ]),
      ),
    );
  }
}

/// The last five manga finished (AniList list, newest first), each sealed with 読了.
class _RecentReads extends StatelessWidget {
  const _RecentReads({required this.pad});
  final double pad;

  static const _shown = {'COMPLETED', 'REPEATING'};

  @override
  Widget build(BuildContext context) {
    final recent = Services.i.session.entries.where((e) => _shown.contains(e.status)).take(5).toList();
    if (recent.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 34),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: pad),
          child: Text(context.isEn ? 'Read recently' : 'Lus récemment', style: Txt.h2(context).copyWith(fontSize: 26)),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 262,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: pad),
            itemCount: recent.length,
            separatorBuilder: (_, _) => const SizedBox(width: 26),
            itemBuilder: (context, i) => _RecentCard(entry: recent[i], index: i),
          ),
        ),
      ]),
    );
  }
}

class _RecentCard extends StatelessWidget {
  const _RecentCard({required this.entry, required this.index});
  final AniEntry entry;
  final int index;

  @override
  Widget build(BuildContext context) {
    final m = entry.media;
    final done = entry.status == 'COMPLETED' || entry.status == 'REPEATING';
    final sub = done
        ? (context.isEn ? 'Finished' : 'Terminé')
        : '${context.t('home.chapter')} ${entry.progress}${m.chapters != null ? ' / ${m.chapters}' : ''}';
    final tag = 'recent-${m.id}';
    return SizedBox(
      width: 140,
      child: Pressable(
        onTap: () => Navigator.of(context).push(SoftRoute(MangaPage.anilist(m, heroTag: tag))),
        child: OneShot(
          delay: Duration(milliseconds: 900 + 70 * index),
          duration: const Duration(milliseconds: 420),
          builder: (context, t, child) => Opacity(
            opacity: t.clamp(0.0, 1.0),
            child: Transform.translate(offset: Offset(0, (1 - const Cubic(0.2, 1.2, 0.4, 1).transform(t)) * -26), child: child),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              width: 140,
              height: 200,
              child: Stack(clipBehavior: Clip.none, children: [
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(boxShadow: [BoxShadow(color: inkBlack, offset: Offset(5, 5))]),
                    foregroundDecoration: BoxDecoration(border: Border.all(color: inkBlack, width: 2)),
                    child: CoverImage(url: m.cover, radius: 0, title: m.title, heroTag: tag),
                  ),
                ),
                if (done) Positioned(right: -10, bottom: -8, child: HankoStamp(size: 50, delay: Duration(milliseconds: 1250 + 90 * index))),
                if (entry.status == 'CURRENT')
                  const Positioned(right: 14, top: -10, width: 16, height: 50, child: BrushShape(Brush.ribbon, color: inkRed)),
              ]),
            ),
            const SizedBox(height: 12),
            Text(m.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Txt.label(context).copyWith(fontSize: 14)),
            const SizedBox(height: 2),
            Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: Txt.caption(context).copyWith(fontSize: 12)),
          ]),
        ),
      ),
    );
  }
}

/// A book seen from its spine: the cover cropped to a strip, with a title band.
class _Spine extends StatelessWidget {
  const _Spine({required this.entry, required this.width, required this.height, required this.band});
  final AniEntry entry;
  final double width, height;
  final (Color, Color) band;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(border: Border.all(color: inkBlack, width: 2)),
      child: Stack(fit: StackFit.expand, children: [
        if (entry.media.cover != null)
          Image.network(Net.image(entry.media.cover!), fit: BoxFit.cover, cacheHeight: (height * MediaQuery.devicePixelRatioOf(context)).round(), alignment: const Alignment(-0.76, 0), errorBuilder: (_, _, _) => const SizedBox()),
        Center(
          child: Container(
            width: 16,
            margin: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(color: band.$1, border: Border.all(color: inkBlack, width: 1.5)),
            child: RotatedBox(
              quarterTurns: 1,
              child: Text(
                entry.media.title.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.clip,
                textAlign: TextAlign.center,
                style: Txt.tag(context).copyWith(fontSize: 9, letterSpacing: 1, color: band.$2, height: 1.3),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

