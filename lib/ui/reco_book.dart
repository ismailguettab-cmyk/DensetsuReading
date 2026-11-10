import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../anilist/anilist.dart';
import '../anilist/recommender.dart';
import '../core/l10n.dart';
import '../core/motion.dart';
import '../core/services.dart';
import '../core/theme.dart';
import 'ink.dart';
import 'manga_page.dart';
import 'reco_symbols.dart';
import 'widgets.dart';

/// Quick fade so the book page's own ink burst carries the transition.
class InkBurstRoute<T> extends PageRouteBuilder<T> {
  InkBurstRoute(Widget page)
      : super(
          opaque: true,
          transitionDuration: const Duration(milliseconds: 180),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (_, _, _) => page,
          transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
        );
}

/// A recommendation category opened as a manga: ink bursts, drops fly, and a two-page
/// spread unfolds. Read right to left; each pick is a panel on the page.
class RecoBookPage extends StatefulWidget {
  const RecoBookPage({super.key, required this.rowKey});

  /// The category's key: the row is read from the recommender, so a reload shows up here.
  final String rowKey;

  @override
  State<RecoBookPage> createState() => _RecoBookPageState();
}

class _RecoBookPageState extends State<RecoBookPage> {
  int _spread = 0;
  int _dir = 1;
  bool _reloading = false;

  RecoRow? get _row => Services.i.reco.rows.where((r) => r.key == widget.rowKey).firstOrNull;
  int get _spreads => max(1, ((_row?.items.length ?? 0) / 6).ceil());

  Future<void> _reload() async {
    if (_reloading) return;
    setState(() => _reloading = true);
    await Services.i.reco.redrawRow(widget.rowKey);
    if (!mounted) return;
    // The new picks are in place under the ink; the strokes leave as _reloading drops.
    setState(() {
      _reloading = false;
      _spread = 0;
    });
  }

  void _turn(int delta) {
    final next = (_spread + delta).clamp(0, _spreads - 1);
    if (next == _spread) return;
    setState(() {
      _dir = delta;
      _spread = next;
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: Services.i.reco, builder: (context, _) => _build(context));

  Widget _build(BuildContext context) {
    final row = _row;
    if (row == null) return const Scaffold(backgroundColor: inkPaper);
    if (_spread >= _spreads) _spread = _spreads - 1;
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= 900;
    final spreadW = min(940.0, size.width - (wide ? 220 : 40));
    final spreadH = spreadW * 580 / 940;
    final items = row.items;
    List<AniMedia> page(int p) => items.skip(p * 3).take(3).toList();

    return Scaffold(
      backgroundColor: inkPaper,
      body: Stack(children: [
        // Ink burst behind the book.
        Center(
          child: OneShot(
            delay: const Duration(milliseconds: 120),
            duration: const Duration(milliseconds: 450),
            builder: (context, t, child) => Transform.scale(
              scale: const Cubic(0.2, 1.3, 0.4, 1).transform(t),
              child: Transform.rotate(angle: (1 - t) * -10 * pi / 180, child: child),
            ),
            child: InkBlot(width: size.width * 1.1, height: size.height * 0.95),
          ),
        ),
        // Drops flying out.
        for (final (dx, dy, s, red) in const [(-0.38, -0.32, 18.0, false), (0.41, -0.28, 12.0, true), (-0.44, 0.3, 14.0, false), (0.36, 0.36, 22.0, false), (0.05, -0.44, 10.0, true), (-0.1, 0.46, 12.0, false)])
          Center(
            child: OneShot(
              delay: const Duration(milliseconds: 180),
              duration: const Duration(milliseconds: 400),
              builder: (context, t, child) {
                final e = const Cubic(0.1, 0.8, 0.2, 1).transform(t);
                return Transform.translate(offset: Offset(dx * size.width * e, dy * size.height * e), child: Transform.scale(scale: 0.2 + 0.8 * e, child: child));
              },
              child: Container(width: s, height: s, decoration: BoxDecoration(color: red ? inkRed : inkBlack, shape: BoxShape.circle)),
            ),
          ),
        SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 18, 28, 0),
              child: Row(children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                    color: inkBlack,
                    child: Wrap(crossAxisAlignment: WrapCrossAlignment.end, spacing: 14, children: [
                      Text(context.isEn ? row.labelEn : row.labelFr, style: GoogleFonts.notoSerifJp(fontSize: 34, fontWeight: FontWeight.w800, color: inkPaper, height: 1)),
                      Text(
                        '${items.length} ${context.isEn ? 'picks · reads right to left' : 'recommandations · se lit de droite à gauche'}',
                        style: Txt.caption(context).copyWith(color: const Color(0xFFCFC6B5), fontSize: 13),
                      ),
                    ]),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  color: inkBlack,
                  child: Text(
                    '${context.isEn ? 'Spread' : 'Double page'} ${_spread + 1} / $_spreads',
                    style: Txt.label(context).copyWith(color: inkPaper, fontSize: 14),
                  ),
                ),
                const SizedBox(width: 16),
                _RoundButton(
                  icon: Icons.refresh_rounded,
                  label: context.isEn ? 'Reload: new picks' : 'Recharger : nouvelles suggestions',
                  busy: _reloading,
                  onTap: _reload,
                ),
                const SizedBox(width: 12),
                _RoundButton(icon: Icons.close_rounded, label: context.t('common.close'), onTap: () => Navigator.of(context).maybePop()),
              ]),
            ),
            Expanded(
              child: Center(
                child: OneShot(
                  delay: const Duration(milliseconds: 300),
                  duration: const Duration(milliseconds: 650),
                  builder: (context, t, child) {
                    // The book flies in small, then opens flat.
                    final fly = const Cubic(0.7, 0, 0.2, 1).transform((t / 0.55).clamp(0.0, 1.0));
                    final open = const Cubic(0.6, 0, 0.3, 1).transform(((t - 0.35) / 0.65).clamp(0.0, 1.0));
                    return Opacity(
                      opacity: fly,
                      child: Transform.translate(
                        offset: Offset(0, 140 * (1 - fly)),
                        child: Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 1 / 2400)
                            ..scaleByDouble(0.4 + 0.6 * fly, 0.4 + 0.6 * fly, 1, 1)
                            ..rotateY((1 - open) * 0.9),
                          child: child,
                        ),
                      ),
                    );
                  },
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    // Right-to-left: "next" sits on the left.
                    _RoundButton(icon: Icons.chevron_left_rounded, label: context.isEn ? 'Next page' : 'Page suivante', onTap: _spread < _spreads - 1 ? () => _turn(1) : null),
                    const SizedBox(width: 22),
                    SizedBox(
                      width: spreadW,
                      height: spreadH,
                      // Reload: straight ink strokes cover the magazine, then wipe off onto the new picks.
                      child: InkReload(
                        busy: _reloading,
                        child: AnimatedSwitcher(
                        // No page turn when the picks change under the reload ink.
                        duration: Motion.reduced(context) || _reloading ? Duration.zero : const Duration(milliseconds: 550),
                        switchInCurve: const Cubic(0.5, 0, 0.3, 1),
                        transitionBuilder: (child, a) => AnimatedBuilder(
                          animation: a,
                          builder: (context, c) => Transform(
                            alignment: _dir > 0 ? Alignment.centerRight : Alignment.centerLeft,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 1 / 2400)
                              ..rotateY((1 - a.value) * (_dir > 0 ? pi / 2 : -pi / 2)),
                            child: c,
                          ),
                          child: child,
                        ),
                        child: Row(key: ValueKey('${row.items.firstOrNull?.id}-$_spread'), children: [
                          Expanded(child: _MangaPage(items: page(_spread * 2 + 1), number: _spread * 2 + 2, left: true, sfx: bookSfx[row.key])),
                          Expanded(child: _MangaPage(items: page(_spread * 2), number: _spread * 2 + 1, left: false, sfx: bookSfx[row.key])),
                        ]),
                      ),
                      ),
                    ),
                    const SizedBox(width: 22),
                    _RoundButton(icon: Icons.chevron_right_rounded, label: context.isEn ? 'Previous page' : 'Page précédente', onTap: _spread > 0 ? () => _turn(-1) : null),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.label, this.onTap, this.busy = false});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: label,
        child: Pressable(
          onTap: onTap,
          child: AnimatedOpacity(
            duration: Motion.fast,
            opacity: onTap == null ? 0.3 : 1,
            child: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(color: inkBlack, shape: BoxShape.circle, border: Border.all(color: inkPaper, width: 2)),
              child: busy
                  ? const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: inkPaper)))
                  : Icon(icon, color: inkPaper, size: 26),
            ),
          ),
        ),
      );
}

/// One manga page: a big panel on top, two below, cut at a slant.
class _MangaPage extends StatelessWidget {
  const _MangaPage({required this.items, required this.number, required this.left, this.sfx});
  final List<AniMedia> items;
  final int number;
  final bool left;
  final String? sfx;

  static const _panels = [
    [Offset(0, 0), Offset(1, 0), Offset(1, 0.56), Offset(0, 0.61)],
    [Offset(0, 0.65), Offset(0.53, 0.62), Offset(0.49, 1), Offset(0, 1)],
    [Offset(0.57, 0.615), Offset(1, 0.6), Offset(1, 1), Offset(0.53, 1)],
  ];
  static const _sfx = ['DON!', 'BAM!', 'ZOOM!', 'GO!', 'BOOM!', 'WOW!'];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F1E4),
        border: Border(
          top: const BorderSide(color: inkBlack, width: 2),
          bottom: const BorderSide(color: inkBlack, width: 2),
          left: left ? const BorderSide(color: inkBlack, width: 2) : BorderSide.none,
          right: const BorderSide(color: inkBlack, width: 2),
        ),
      ),
      child: Stack(children: [
        // Gutter shadow toward the spine.
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: left ? Alignment.centerRight : Alignment.centerLeft,
                end: left ? Alignment.centerLeft : Alignment.centerRight,
                colors: const [Color(0x40121010), Color(0x00121010)],
                stops: const [0, 0.08],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 30),
          child: LayoutBuilder(builder: (context, box) {
            final s = Size(box.maxWidth, box.maxHeight);
            final shapes = [
              for (var i = 0; i < items.length; i++) [for (final o in _panels[i]) Offset(o.dx * s.width, o.dy * s.height)],
            ];
            // One tap handler for the whole page: the panel whose shape holds the finger opens.
            // (Each panel covers the page and is only cut to shape when painted, so per-panel
            // hit testing let one panel swallow every tap.)
            return MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (d) {
                  for (var i = 0; i < shapes.length; i++) {
                    if ((Path()..addPolygon(shapes[i], true)).contains(d.localPosition)) {
                      Navigator.of(context).push(SoftRoute(MangaPage.anilist(items[i])));
                      return;
                    }
                  }
                },
                child: IgnorePointer(
                  child: Stack(children: [
                    for (var i = 0; i < items.length; i++)
                      Positioned.fill(
                        child: _Panel(
                          media: items[i],
                          shape: shapes[i],
                          big: i == 0,
                          sfx: sfx ?? _sfx[(number + i) % _sfx.length],
                          delay: Duration(milliseconds: 650 + (left ? 3 : 0) * 120 + i * 120),
                        ),
                      ),
                  ]),
                ),
              ),
            );
          }),
        ),
        Positioned(
          left: left ? 18 : null,
          right: left ? null : 18,
          bottom: 8,
          child: Text('$number', style: Txt.caption(context).copyWith(fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.media, required this.shape, required this.big, required this.sfx, required this.delay});
  final AniMedia media;
  final List<Offset> shape;
  final bool big;
  final String sfx;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    final bounds = Rect.fromPoints(
      Offset(shape.map((o) => o.dx).reduce(min), shape.map((o) => o.dy).reduce(min)),
      Offset(shape.map((o) => o.dx).reduce(max), shape.map((o) => o.dy).reduce(max)),
    );
    final score = media.meanScore != null ? '★ ${(media.meanScore! / 10).toStringAsFixed(1).replaceAll('.', ',')}' : null;
    return OneShot(
          delay: delay,
          duration: const Duration(milliseconds: 800),
          builder: (context, t, child) {
            final wipe = const Cubic(0.75, 0, 0.25, 1).transform((t / 0.48).clamp(0.0, 1.0));
            final color = Curves.easeOut.transform(((t - 0.35) / 0.65).clamp(0.0, 1.0));
            final slam = ((t - 0.5) / 0.4).clamp(0.0, 1.0);
            return Stack(children: [
              ClipPath(
                clipper: _PolyClipper(shape),
                child: Stack(children: [
                  Positioned.fromRect(
                    rect: bounds,
                    child: big ? _BigContent(media: media, color: color, sfx: sfx, slam: slam) : Colorized(t: color, child: CoverImage(url: media.cover, radius: 0)),
                  ),
                  // Paper wipe that slides off to reveal the panel.
                  Positioned.fromRect(
                    rect: bounds,
                    child: FractionalTranslation(translation: Offset(-1.18 * wipe, 0), child: const ColoredBox(color: Color(0xFFF7F1E4))),
                  ),
                ]),
              ),
              IgnorePointer(child: CustomPaint(size: Size.infinite, painter: _PolyBorder(shape))),
              // Small caption at the panel's foot: title and score only, so the cover stays visible.
              Positioned(
                left: bounds.left + 8,
                top: bounds.bottom - (score != null ? 44 : 30),
                child: Opacity(
                  opacity: color,
                  child: Container(
                    constraints: BoxConstraints(maxWidth: bounds.width * (big ? 0.5 : 0.78)),
                    padding: const EdgeInsets.fromLTRB(7, 3, 7, 4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFBF8F1),
                      border: Border.fromBorderSide(BorderSide(color: inkBlack, width: 1.5)),
                      boxShadow: [BoxShadow(color: inkBlack, offset: Offset(2, 2))],
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text(media.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Txt.label(context).copyWith(fontSize: big ? 13 : 11.5, height: 1.15)),
                      if (score != null) Text(score, style: Txt.caption(context).copyWith(fontSize: 10.5, fontWeight: FontWeight.w700, color: inkRed, height: 1.2)),
                    ]),
                  ),
                ),
              ),
            ]);
          },
        );
  }
}

/// The big panel: focus lines, the cover tilted with an ink shadow, and a slammed sound effect.
class _BigContent extends StatelessWidget {
  const _BigContent({required this.media, required this.color, required this.sfx, required this.slam});
  final AniMedia media;
  final double color, slam;
  final String sfx;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final h = box.maxHeight * 0.86, w = h * 150 / 214;
      final s = slam == 0 ? 0.0 : (slam < 0.6 ? 2.6 - 1.68 * (slam / 0.6) : 0.92 + 0.08 * ((slam - 0.6) / 0.4));
      return Stack(clipBehavior: Clip.none, children: [
        const Positioned.fill(child: CustomPaint(painter: _FocusLines(Alignment(0.36, 0)))),
        Positioned(
          left: box.maxWidth * 0.68 - w / 2,
          top: (box.maxHeight - h) / 2,
          width: w,
          height: h,
          child: Transform.rotate(
            angle: 3 * pi / 180,
            child: Container(
              decoration: const BoxDecoration(boxShadow: [BoxShadow(color: inkBlack, offset: Offset(6, 6))]),
              foregroundDecoration: BoxDecoration(border: Border.all(color: inkBlack, width: 3)),
              child: Colorized(t: color, child: CoverImage(url: media.cover, radius: 0)),
            ),
          ),
        ),
        if (slam > 0)
          Positioned(
            left: box.maxWidth * 0.08,
            top: box.maxHeight * 0.1,
            child: Opacity(
              opacity: (slam / 0.3).clamp(0.0, 1.0),
              child: Transform.rotate(
                angle: -8 * pi / 180,
                child: Transform.scale(
                  scale: s,
                  child: Stack(children: [
                    Text(sfx, style: GoogleFonts.bangers(fontSize: 44, letterSpacing: 1, foreground: Paint()
                      ..style = PaintingStyle.stroke
                      ..strokeWidth = 6
                      ..color = inkBlack)),
                    Text(sfx, style: GoogleFonts.bangers(fontSize: 44, letterSpacing: 1, color: inkRed)),
                  ]),
                ),
              ),
            ),
          ),
      ]);
    });
  }
}

class _FocusLines extends CustomPainter {
  const _FocusLines(this.center);
  final Alignment center;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFF7F1E4));
    final c = center.alongSize(size);
    final r = size.longestSide * 1.2;
    final paint = Paint()..color = inkBlack;
    for (var a = 0.0; a < 2 * pi; a += 5 * pi / 180) {
      final a2 = a + 0.9 * pi / 180;
      canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy)
          ..lineTo(c.dx + cos(a) * r, c.dy + sin(a) * r)
          ..lineTo(c.dx + cos(a2) * r, c.dy + sin(a2) * r)
          ..close(),
        paint,
      );
    }
    canvas.drawOval(Rect.fromCenter(center: c, width: size.width * 0.5, height: size.height * 0.5), Paint()..color = const Color(0xFFF7F1E4));
  }

  @override
  bool shouldRepaint(_FocusLines old) => false;
}

class _PolyClipper extends CustomClipper<Path> {
  _PolyClipper(this.points);
  final List<Offset> points;

  @override
  Path getClip(Size size) => Path()..addPolygon(points, true);

  @override
  bool shouldReclip(_PolyClipper old) => old.points != points;
}

class _PolyBorder extends CustomPainter {
  _PolyBorder(this.points);
  final List<Offset> points;

  @override
  void paint(Canvas canvas, Size size) => canvas.drawPath(
        Path()..addPolygon(points, true),
        Paint()
          ..color = inkBlack
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeJoin = StrokeJoin.miter,
      );

  @override
  bool shouldRepaint(_PolyBorder old) => old.points != points;
}
