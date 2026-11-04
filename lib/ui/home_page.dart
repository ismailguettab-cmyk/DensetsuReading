import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../anilist/anilist.dart';
import '../core/activity.dart';
import '../core/l10n.dart';
import '../core/motion.dart';
import '../core/net.dart';
import '../core/services.dart';
import '../core/theme.dart';
import '../sources/catalog.dart';
import 'library_page.dart';
import 'manga_page.dart';
import 'shell.dart';
import 'widgets.dart';

/// Profile: counts (each one opens its list), the manga to resume, what was read recently.
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
          final read = session.withStatus(LibraryShelf.read.statuses);
          final reading = session.withStatus(LibraryShelf.reading.statuses);
          final planning = session.withStatus(LibraryShelf.planning.statuses);
          final recent = session.withStatus({'COMPLETED', 'REPEATING'}).take(10).toList();
          final resume = s.activity.reads.isEmpty ? null : s.activity.reads.first;
          final pad = pagePadding(context);

          void open(LibraryShelf shelf) => Navigator.of(context).push(SoftRoute(LibraryPage(initial: shelf)));

          return RefreshIndicator(
            onRefresh: session.refresh,
            color: context.pal.accent,
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _Hero(user: user),
                Padding(
                  padding: EdgeInsets.fromLTRB(pad.left, 0, pad.right, 0),
                  child: _Stats(cards: [
                    _StatData(context.t('home.read'), read.length, Icons.done_all_rounded, read, () => open(LibraryShelf.read)),
                    _StatData(context.t('home.reading'), reading.length, Icons.auto_stories_rounded, reading, () => open(LibraryShelf.reading)),
                    _StatData(context.t('home.planning'), planning.length, Icons.bookmark_rounded, planning, () => open(LibraryShelf.planning)),
                  ]),
                ),
                if (resume != null) ...[
                  const SizedBox(height: 44),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: pad.left),
                    child: Reveal(index: 5, child: SectionTitle(context.t('home.continue'))),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: pad.left),
                    child: Reveal(index: 6, offset: 24, child: _ResumeCard(event: resume)),
                  ),
                ],
                const SizedBox(height: 44),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: pad.left),
                  child: Reveal(index: 7, child: SectionTitle(context.t('home.recent'))),
                ),
                if (recent.isEmpty)
                  Padding(padding: EdgeInsets.symmetric(horizontal: pad.left), child: Text(context.t('home.empty'), style: Txt.body(context)))
                else
                  _RecentRow(entries: recent, padding: pad.left),
                SizedBox(height: pad.bottom),
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
      height: 262,
      child: Stack(fit: StackFit.expand, children: [
        if (user.banner != null)
          Reveal(
            offset: 0,
            child: Opacity(
              opacity: 0.5,
              child: Image.network(Net.image(user.banner!), fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox()),
            ),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [p.bg.withValues(alpha: user.banner == null ? 0 : 0.15), p.bg],
            ),
          ),
        ),
        Positioned(
          left: pad.left,
          right: pad.right,
          bottom: 32,
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

class _StatData {
  const _StatData(this.label, this.value, this.icon, this.entries, this.onTap);
  final String label;
  final int value;
  final IconData icon;
  final List<AniEntry> entries;
  final VoidCallback? onTap;
}

class _Stats extends StatelessWidget {
  const _Stats({required this.cards});
  final List<_StatData> cards;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final columns = box.maxWidth >= 640 ? 3 : 1;
      const gap = 16.0;
      final w = (box.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(spacing: gap, runSpacing: gap, children: [
        for (var i = 0; i < cards.length; i++)
          SizedBox(width: w, height: 176, child: Reveal(index: 2 + i, offset: 22, child: _StatCard(data: cards[i], index: i))),
      ]);
    });
  }
}

/// A count with a fan of the covers it stands for. The fan deals itself in once,
/// then opens a little wider under the pointer; the card tilts toward it.
class _StatCard extends StatefulWidget {
  const _StatCard({required this.data, required this.index});
  final _StatData data;
  final int index;

  @override
  State<_StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<_StatCard> with SingleTickerProviderStateMixin {
  late final _deal = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  bool _hover = false;
  int _rolls = 0;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 260 + widget.index * 90), () {
      if (mounted) _deal.forward();
    });
  }

  @override
  void dispose() {
    _deal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final d = widget.data;
    final covers = [for (final e in d.entries.take(3)) e.media.cover].reversed.toList();
    final card = Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _hover && d.onTap != null ? p.accent.withValues(alpha: 0.45) : p.line),
      ),
      child: Stack(children: [
        if (covers.isNotEmpty)
          Positioned(right: -8, top: 16, width: 128, height: 150, child: _Fan(covers: covers, deal: _deal, open: _hover)),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: p.accentSoft, borderRadius: BorderRadius.circular(11)),
              child: Icon(d.icon, size: 18, color: p.accent),
            ),
            const Spacer(),
            RollingNumber(value: d.value, replay: _rolls, style: Txt.number(context, size: 34)),
            const SizedBox(height: 6),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Text(d.label, style: Txt.caption(context).copyWith(fontSize: 13, color: p.text2)),
              if (d.onTap != null) ...[
                const SizedBox(width: 4),
                AnimatedSlide(
                  offset: Offset(_hover ? 0.25 : 0, 0),
                  duration: Motion.fast,
                  curve: Motion.easeOut,
                  child: Icon(Icons.arrow_forward_rounded, size: 14, color: _hover ? p.accent : p.text3),
                ),
              ],
            ]),
          ]),
        ),
      ]),
    );
    if (d.onTap == null) return card;
    return MouseRegion(
      onEnter: (_) => setState(() {
        _hover = true;
        _rolls++;
      }),
      onExit: (_) => setState(() => _hover = false),
      child: Tilt(maxAngle: 0.09, child: Pressable(onTap: d.onTap, child: card)),
    );
  }
}

/// Three covers dealt like cards. Composite-only: rotation and translation.
class _Fan extends StatelessWidget {
  const _Fan({required this.covers, required this.deal, required this.open});
  final List<String?> covers;
  final AnimationController deal;
  final bool open;

  @override
  Widget build(BuildContext context) {
    final n = covers.length;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: open ? 1 : 0),
      duration: const Duration(milliseconds: 420),
      curve: Motion.easeOut,
      builder: (context, spread, _) => AnimatedBuilder(
        animation: deal,
        builder: (context, _) => Stack(clipBehavior: Clip.none, children: [
          for (var i = 0; i < n; i++) _card(i, n, spread),
        ]),
      ),
    );
  }

  Widget _card(int i, int n, double spread) {
    // Each card arrives a little after the previous one.
    final start = i * 0.16;
    final t = Curves.easeOutBack.transform(((deal.value - start) / (1 - start)).clamp(0.0, 1.0));
    final slot = n == 1 ? 0.0 : (i / (n - 1)) * 2 - 1; // -1 … 1
    final angle = (slot * (0.2 + 0.08 * spread)) * t;
    final dx = slot * (22 + 16 * spread) * t;
    final dy = (1 - t) * 90 - (spread * 8) * (1 - slot.abs());
    return Positioned(
      left: 36,
      top: 6,
      child: Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform(
          alignment: Alignment.bottomCenter,
          transform: Matrix4.identity()
            ..translateByDouble(dx, dy, 0, 1)
            ..rotateZ(angle),
          child: SizedBox(
            width: 56,
            height: 84,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 14, offset: Offset(0, 6))],
              ),
              child: CoverImage(url: covers[i], radius: 8),
            ),
          ),
        ),
      ),
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
    final headers = source?.imageHeaders ?? const <String, String>{};
    return Pressable(
      scale: 0.985,
      onTap: source == null ? null : () => Navigator.of(context).push(SoftRoute(MangaPage.resume(event))),
      child: Container(
        height: 190,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: p.line)),
        child: Stack(fit: StackFit.expand, children: [
          // Static blurred cover as a backdrop: blurred once, never animated.
          if (event.cover != null)
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
              child: Opacity(opacity: 0.45, child: CoverImage(url: event.cover, headers: headers, radius: 0)),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [p.surface.withValues(alpha: 0.35), p.surface.withValues(alpha: 0.92)], stops: const [0, 0.55]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(children: [
              SizedBox(
                width: 104,
                child: Tilt(
                  maxAngle: 0.18,
                  lift: 1.04,
                  child: AspectRatio(
                    aspectRatio: 2 / 3,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 22, offset: Offset(0, 12))],
                      ),
                      child: CoverImage(url: event.cover, headers: headers, radius: 12, title: event.title),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 26),
              Expanded(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(context.ago(event.at), style: Txt.caption(context).copyWith(color: p.accent, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text(event.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Txt.h1(context).copyWith(fontSize: 24)),
                  const SizedBox(height: 8),
                  Text(
                    '${event.chapterName}  ·  ${context.t('reader.page')} ${event.page + 1}  ·  ${source?.name ?? ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Txt.caption(context).copyWith(fontSize: 13, color: p.text2),
                  ),
                ]),
              ),
              const SizedBox(width: 16),
              const _PlayButton(),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Play button that settles in with a single soft overshoot when it appears.
class _PlayButton extends StatelessWidget {
  const _PlayButton();

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final button = Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: p.cta,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: p.cta.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: Icon(Icons.play_arrow_rounded, size: 30, color: p.onCta),
    );
    if (Motion.reduced(context)) return button;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.6, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.elasticOut,
      builder: (_, s, child) => Transform.scale(scale: s, child: child),
      child: button,
    );
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({required this.entries, required this.padding});
  final List<AniEntry> entries;
  final double padding;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 318,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding: EdgeInsets.symmetric(horizontal: padding),
        itemCount: entries.length,
        separatorBuilder: (_, _) => const SizedBox(width: 20),
        itemBuilder: (context, i) => _SlideIn(index: i, child: _RecentCard(entry: entries[i], index: i)),
      ),
    );
  }
}

/// Slides in from the right, staggered, once.
class _SlideIn extends StatefulWidget {
  const _SlideIn({required this.index, required this.child});
  final int index;
  final Widget child;

  @override
  State<_SlideIn> createState() => _SlideInState();
}

class _SlideInState extends State<_SlideIn> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 620));
  late final _t = CurvedAnimation(parent: _c, curve: Motion.easeOut);

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 420 + 70 * min(widget.index, 8)), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = Motion.reduced(context);
    return FadeTransition(
      opacity: _t,
      child: reduced
          ? widget.child
          : AnimatedBuilder(
              animation: _t,
              builder: (_, child) => Transform.translate(offset: Offset((1 - _t.value) * 60, 0), child: child),
              child: widget.child,
            ),
    );
  }
}

/// Red hanko-style "finished" seal: 読了 (finished reading) dominant, "Terminé" small.
/// It is struck onto the cover once: drops from above, slightly too big and turned,
/// lands with a short squash, and leaves a faint ink ring that fades.
class _Stamp extends StatefulWidget {
  const _Stamp({required this.delay});
  final Duration delay;

  @override
  State<_Stamp> createState() => _StampState();
}

class _StampState extends State<_Stamp> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 620));

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  static const _red = Color(0xFFD93A2B);

  @override
  Widget build(BuildContext context) {
    final seal = Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xE6FFF7F0), // paper, so the red ink reads on any cover
        border: Border.all(color: _red.withValues(alpha: 0.92), width: 3),
        boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 8, offset: Offset(0, 3))],
      ),
      padding: const EdgeInsets.all(3),
      child: Container(
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _red.withValues(alpha: 0.85), width: 1.2)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('読了', style: GoogleFonts.notoSerifJp(fontSize: 22, height: 1, fontWeight: FontWeight.w900, color: _red)),
          const SizedBox(height: 2),
          Text(
            context.isEn ? 'FINISHED' : 'TERMINÉ',
            style: TextStyle(fontSize: 7.5, height: 1, fontWeight: FontWeight.w800, letterSpacing: 1.1, color: _red.withValues(alpha: 0.95)),
          ),
        ]),
      ),
    );
    if (Motion.reduced(context)) return Transform.rotate(angle: -0.21, child: seal);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final v = _c.value;
        // 0–0.45: falls onto the page (accelerating, like a hand pressing); 0.45–1: squash and settle.
        final fall = Curves.easeInCubic.transform((v / 0.45).clamp(0.0, 1.0));
        final settle = ((v - 0.45) / 0.55).clamp(0.0, 1.0);
        final squash = 1 - 0.08 * sin(settle * pi) * (1 - settle);
        final scale = (1.9 - 0.9 * fall) * squash;
        final angle = -0.55 + 0.34 * fall;
        final ring = settle > 0 ? (1 - settle) : 0.0;
        return Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
          if (ring > 0)
            Transform.scale(
              scale: 1 + 0.5 * settle,
              child: Opacity(
                opacity: ring * 0.5,
                child: DecoratedBox(
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _red, width: 2)),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          Opacity(
            opacity: fall.clamp(0.0, 1.0),
            child: Transform.rotate(angle: angle, child: Transform.scale(scale: scale, child: child)),
          ),
        ]);
      },
      child: seal,
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
    final tag = 'recent-${m.id}';
    return Pressable(
      onTap: () => Navigator.of(context).push(SoftRoute(MangaPage.anilist(m, heroTag: tag))),
      child: SizedBox(
        width: 168,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Tilt(
            child: AspectRatio(
              aspectRatio: 2 / 3,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 20, offset: Offset(0, 10))],
                ),
                child: Stack(fit: StackFit.expand, children: [
                  CoverImage(url: m.cover, radius: 14, heroTag: tag, title: m.title),
                  Positioned(right: 6, bottom: 8, width: 78, height: 78, child: _Stamp(delay: Duration(milliseconds: 700 + 90 * index))),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(m.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Txt.title(context).copyWith(fontSize: 14)),
          const SizedBox(height: 4),
          Text(context.ago(entry.updated), style: Txt.caption(context)),
        ]),
      ),
    );
  }
}
