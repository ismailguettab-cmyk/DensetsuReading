import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_drawing/path_drawing.dart';

import '../core/motion.dart';
import '../core/net.dart';
import '../core/services.dart';
import '../core/theme.dart';
import 'widgets.dart';

/// Day-mode ink kit, drawn from the style guide: brush strokes, ensō, seal stamp,
/// ink sweep between pages. Every animation is transform / clip / opacity only.

const inkRed = Color(0xFFB5121B);
const inkBlack = Color(0xFF121010);
const inkPaper = Color(0xFFF2EBDD);

/// Brush curves from the style guide (dry edges, on-off pressure).
const _sweepRight =
    'M4 50C26 30 70 20 124 18c64-2 136 2 206 7 28 2 52 5 66 12 5 3 2 8-4 8-36 0-62 6-110 9-72 4-152 9-224 12-26 1-46-1-56-8-6-4-4-8 2-8z';
const _sweepLeft =
    'M396 44C372 26 330 20 276 18c-64-2-136 4-206 9-28 2-52 6-64 13-4 3-2 8 4 8 38 0 60 6 110 8 72 4 150 8 222 10 26 1 46-2 54-9 6-4 4-8-2-8z';
const _sweepThin = 'M6 46c30-14 80-20 140-20 70 0 150 4 214 12 22 3 34 8 30 12-30 4-80 4-140 6-80 2-170 4-226 2-18-1-26-6-18-12z';
const _divider = 'M2 16C60 8 200 5 420 6c230 1 420 3 570 7 8 1 10 5 2 7-150 5-350 7-580 7C200 27 70 24 6 21c-6-1-8-4-4-5z';
const _plank = 'M0 2h400v10c-30 2-50 4-90 4-60 0-120-2-200-2-50 0-90 2-110 2z';
const _underline = 'M2 12C40 4 120 3 198 8c2 4 0 7-3 7-70 2-130 3-190 2-4 0-5-3-3-5z';
const portraitMask =
    'M78 0h322v372H46c-12-26 8-50-4-80-10-26-32-42-22-76 8-28 32-38 28-70-4-30-22-46-12-82C42 40 60 16 78 0z';
const _portraitEdge =
    'M78 0c-18 16-36 40-42 64-10 36 8 52 12 82 4 32-20 42-28 70-10 34 12 50 22 76 12 30-8 54 4 80h16c-10-30 10-52-2-82-10-26-30-42-20-74 8-28 30-38 26-70-4-30-22-46-12-82C40 40 62 18 84 0z';
const _ensoFill = 'M60 8c30 0 52 22 52 52 0 29-24 52-53 52C30 112 8 88 8 60 8 33 28 10 56 8';
const _ensoStroke = 'M56 6C26 8 4 32 6 62c2 30 28 54 58 52 30-2 52-28 50-58-2-24-18-42-40-48';
const _ribbon = 'M2 0h16v60l-8-8-8 8z';

enum Brush { sweepRight, sweepLeft, thin, divider, plank, underline, portraitEdge, ribbon }

const _brushData = {
  Brush.sweepRight: (_sweepRight, Size(400, 90)),
  Brush.sweepLeft: (_sweepLeft, Size(400, 90)),
  Brush.thin: (_sweepThin, Size(400, 90)),
  Brush.divider: (_divider, Size(1000, 30)),
  Brush.plank: (_plank, Size(400, 24)),
  Brush.underline: (_underline, Size(200, 20)),
  Brush.portraitEdge: (_portraitEdge, Size(400, 372)),
  Brush.ribbon: (_ribbon, Size(20, 60)),
};

final _cache = <String, Path>{};
Path _parse(String d) => _cache[d] ??= parseSvgPathData(d);

Path scaledPath(String d, Size viewBox, Size size) {
  final m = Matrix4.diagonal3Values(size.width / viewBox.width, size.height / viewBox.height, 1);
  return _parse(d).transform(m.storage);
}

/// One brush shape stretched to its box.
class BrushShape extends StatelessWidget {
  const BrushShape(this.brush, {super.key, this.color = inkBlack});
  final Brush brush;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _ShapePainter(_brushData[brush]!.$1, _brushData[brush]!.$2, color));
}

class _ShapePainter extends CustomPainter {
  _ShapePainter(this.d, this.viewBox, this.color);
  final String d;
  final Size viewBox;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) => canvas.drawPath(scaledPath(d, viewBox, size), Paint()..color = color);

  @override
  bool shouldRepaint(_ShapePainter old) => old.color != color || old.d != d;
}

/// Clips its child open like a fast brush pass, left→right (or right→left).
/// The style guide's curve: cubic-bezier(.9,0,.3,1), 140–250 ms.
class PaintReveal extends StatefulWidget {
  const PaintReveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 160),
    this.fromRight = false,
    this.curve = const Cubic(0.9, 0, 0.3, 1),
  });

  final Widget child;
  final Duration delay, duration;
  final bool fromRight;
  final Curve curve;

  @override
  State<PaintReveal> createState() => _PaintRevealState();
}

class _PaintRevealState extends State<PaintReveal> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: widget.duration);

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

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) => ClipRect(clipper: _RevealClip(widget.curve.transform(_c.value), widget.fromRight), child: child),
      child: widget.child,
    );
  }
}

class _RevealClip extends CustomClipper<Rect> {
  _RevealClip(this.t, this.fromRight);
  final double t;
  final bool fromRight;

  @override
  Rect getClip(Size s) => fromRight ? Rect.fromLTRB(s.width * (1 - t), -40, s.width + 40, s.height + 40) : Rect.fromLTRB(-40, -40, s.width * t, s.height + 40);

  @override
  bool shouldReclip(_RevealClip old) => old.t != t || old.fromRight != fromRight;
}

/// One-shot entrance driven by a single controller: delay, duration, curve, then a builder.
class OneShot extends StatefulWidget {
  const OneShot({super.key, required this.builder, this.delay = Duration.zero, this.duration = const Duration(milliseconds: 350), this.child, this.start = 0});

  final Widget Function(BuildContext context, double t, Widget? child) builder;
  final Duration delay, duration;
  final Widget? child;

  /// 1 shows the end state straight away (no entrance).
  final double start;

  @override
  State<OneShot> createState() => _OneShotState();
}

class _OneShotState extends State<OneShot> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: widget.duration, value: widget.start);

  @override
  void initState() {
    super.initState();
    if (widget.start >= 1) return;
    Future.delayed(widget.delay, () {
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
    if (Motion.reduced(context)) return widget.builder(context, 1, widget.child);
    return AnimatedBuilder(animation: _c, builder: (context, child) => widget.builder(context, _c.value, child), child: widget.child);
  }
}

/// Small ink drops that pop around a brush stroke.
class InkDots extends StatelessWidget {
  const InkDots({super.key, required this.dots, this.delay = const Duration(milliseconds: 260)});

  /// (x, y) as fractions of the box, radius in px, red or black.
  final List<(double, double, double, bool)> dots;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    return OneShot(
      delay: delay,
      duration: const Duration(milliseconds: 220),
      builder: (context, t, _) => LayoutBuilder(builder: (context, box) {
        final s = const Cubic(0.2, 1.6, 0.4, 1).transform(t);
        return Stack(clipBehavior: Clip.none, children: [
          for (final (x, y, r, red) in dots)
            Positioned(
              left: x * box.maxWidth - r,
              top: y * box.maxHeight - r,
              child: Transform.scale(
                scale: s,
                child: Container(width: r * 2, height: r * 2, decoration: BoxDecoration(color: red ? inkRed : inkBlack, shape: BoxShape.circle)),
              ),
            ),
        ]);
      }),
    );
  }
}

/// Red ensō behind a play triangle; the black ring draws itself once.
class EnsoButton extends StatelessWidget {
  const EnsoButton({super.key, this.size = 70, this.delay = const Duration(milliseconds: 600)});
  final double size;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    return OneShot(
      delay: delay,
      duration: const Duration(milliseconds: 600),
      builder: (context, t, _) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _EnsoPainter(const Cubic(0.7, 0, 0.2, 1).transform(t)),
          child: Center(
            child: Padding(
              padding: EdgeInsets.only(left: size * 0.06),
              child: Icon(Icons.play_arrow_rounded, color: inkPaper, size: size * 0.42),
            ),
          ),
        ),
      ),
    );
  }
}

class _EnsoPainter extends CustomPainter {
  _EnsoPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    const vb = Size(120, 120);
    canvas.drawPath(scaledPath(_ensoFill, vb, size), Paint()..color = inkRed);
    final ring = scaledPath(_ensoStroke, vb, size);
    final paint = Paint()
      ..color = inkBlack
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 5 / 120
      ..strokeCap = StrokeCap.round;
    for (final metric in ring.computeMetrics()) {
      canvas.drawPath(metric.extractPath(0, metric.length * (0.07 + 0.93 * t)), paint);
    }
  }

  @override
  bool shouldRepaint(_EnsoPainter old) => old.t != t;
}

/// Round red seal (読了 etc.) slammed onto a cover: big and turned, then lands at −10°.
class HankoStamp extends StatelessWidget {
  const HankoStamp({super.key, this.text = '読了', this.size = 44, this.delay = Duration.zero, this.caption, this.animate = true});
  final String text;
  final String? caption;
  final double size;
  final Duration delay;

  /// False: already stamped (no slam), e.g. covers reached by scrolling.
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final seal = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xE0F2EBDD),
        border: Border.all(color: inkRed, width: max(2.5, size * 0.065)),
      ),
      alignment: Alignment.center,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(text, style: GoogleFonts.notoSerifJp(fontSize: size * 0.3, fontWeight: FontWeight.w800, color: inkRed, height: 1)),
        if (caption != null)
          Text(caption!, style: GoogleFonts.notoSansJp(fontSize: size * 0.11, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: inkRed, height: 1.2)),
      ]),
    );
    return OneShot(
      delay: delay,
      duration: const Duration(milliseconds: 350),
      start: animate ? 0 : 1,
      builder: (context, t, child) {
        // 0 → .6: falls big and turned; .6 → 1: settles.
        final a = (t / 0.6).clamp(0.0, 1.0), b = ((t - 0.6) / 0.4).clamp(0.0, 1.0);
        final scale = t < 0.6 ? 2.2 - 1.28 * Curves.easeIn.transform(a) : 0.92 + 0.08 * b;
        final deg = t < 0.6 ? -24 + 16 * a : -8 - 2 * b;
        return Opacity(opacity: a, child: Transform.rotate(angle: deg * pi / 180, child: Transform.scale(scale: scale, child: child)));
      },
      child: seal,
    );
  }
}

/// Full-screen ink pass between pages: strokes sweep in, the page changes under the ink,
/// the strokes leave the other way. Used to open a shelf (library) and to go back.
class InkRoute<T> extends PageRouteBuilder<T> {
  InkRoute(Widget page)
      : super(
          transitionDuration: const Duration(milliseconds: 820),
          reverseTransitionDuration: const Duration(milliseconds: 820),
          opaque: true,
          pageBuilder: (_, _, _) => page,
          transitionsBuilder: (context, animation, _, child) {
            if (Motion.reduced(context)) return FadeTransition(opacity: animation, child: child);
            return AnimatedBuilder(
              animation: animation,
              builder: (context, _) {
                final v = animation.value;
                return Stack(children: [
                  // The new page only shows once the ink covers the screen.
                  Opacity(opacity: v >= 0.45 ? 1 : 0, child: child),
                  IgnorePointer(child: CustomPaint(size: Size.infinite, painter: _SweepPainter(v))),
                ]);
              },
            );
          },
        );
}

class _SweepPainter extends CustomPainter {
  _SweepPainter(this.v);
  final double v;

  static const _rows = [
    (Brush.sweepRight, -0.08, 0.34, inkBlack, 0.0, -3.0),
    (Brush.sweepLeft, 0.14, 0.36, inkBlack, 0.05, 2.0),
    (Brush.sweepRight, 0.36, 0.36, inkBlack, 0.10, -2.0),
    (Brush.sweepLeft, 0.58, 0.36, inkRed, 0.15, 3.0),
    (Brush.sweepRight, 0.76, 0.34, inkBlack, 0.20, -2.0),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (final (brush, top, h, color, delay, deg) in _rows) {
      // Same shape forward (push) and backward (pop): in, hold, out.
      final t = ((v - delay * 0.4) / (1 - delay * 0.4)).clamp(0.0, 1.0);
      final inT = const Cubic(0.7, 0, 0.3, 1).transform((t / 0.42).clamp(0.0, 1.0));
      final outT = const Cubic(0.7, 0, 0.3, 1).transform(((t - 0.58) / 0.42).clamp(0.0, 1.0));
      if (inT <= 0 || outT >= 1) continue;
      final fromLeft = brush == Brush.sweepRight;
      final w = size.width * 1.24, x0 = -size.width * 0.12;
      final rect = Rect.fromLTWH(x0, size.height * top, w, size.height * h);
      final visible = fromLeft
          ? Rect.fromLTRB(rect.left + w * outT, rect.top - 60, rect.left + w * inT, rect.bottom + 60)
          : Rect.fromLTRB(rect.right - w * inT, rect.top - 60, rect.right - w * outT, rect.bottom + 60);
      canvas
        ..save()
        ..clipRect(visible)
        ..translate(rect.center.dx, rect.center.dy)
        ..rotate(deg * pi / 180)
        ..translate(-rect.width / 2, -rect.height / 2);
      canvas.drawPath(scaledPath(_brushData[brush]!.$1, _brushData[brush]!.$2, rect.size), Paint()..color = color);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_SweepPainter old) => old.v != v;
}

/// Red brush underline that draws itself under the active tab.
class InkUnderline extends StatelessWidget {
  const InkUnderline({super.key});

  @override
  Widget build(BuildContext context) => PaintReveal(
        duration: const Duration(milliseconds: 300),
        curve: const Cubic(0.8, 0, 0.2, 1),
        child: const SizedBox(height: 10, child: BrushShape(Brush.underline, color: inkRed)),
      );
}

/// A jagged, hand-cut cover edge (style guide's `.cut`).
class CutClipper extends CustomClipper<Path> {
  const CutClipper();

  @override
  Path getClip(Size s) {
    const pts = [
      (0.0, 0.015), (0.10, 0.0), (0.35, 0.012), (0.62, 0.0), (1.0, 0.008),
      (0.994, 0.988), (0.80, 1.0), (0.50, 0.988), (0.22, 1.0), (0.006, 0.99),
    ];
    return Path()..addPolygon([for (final (x, y) in pts) Offset(x * s.width, y * s.height)], true);
  }

  @override
  bool shouldReclip(CutClipper old) => false;
}

/// Ink-style text tag ("REPRENDRE LA LECTURE", "À LIRE").
class InkTag extends StatelessWidget {
  const InkTag(this.text, {super.key, this.color = inkBlack, this.angle = 0});
  final String text;
  final Color color;
  final double angle;

  @override
  Widget build(BuildContext context) => Transform.rotate(
        angle: angle,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          color: color,
          child: Text(text, style: Txt.tag(context).copyWith(color: inkPaper)),
        ),
      );
}

/// A cover laid down on three brush strokes (two black, one red) with ink drops,
/// square ink border and offset shadow — the home and recommendation hero.
class BrushCover extends StatelessWidget {
  const BrushCover({super.key, required this.cover, this.headers = const {}, this.title, this.width = 206});
  final String? cover;
  final Map<String, String> headers;
  final String? title;
  final double width;

  @override
  Widget build(BuildContext context) {
    final w = width, h = w * 296 / 206;
    return SizedBox(
      width: w,
      height: h,
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned(
          left: -w * 0.24,
          top: h * 0.17,
          width: w * 1.5,
          height: 80,
          child: Transform.rotate(angle: -9 * pi / 180, child: const PaintReveal(delay: Duration(milliseconds: 50), child: BrushShape(Brush.sweepRight))),
        ),
        Positioned(
          left: -w * 0.2,
          top: h * 0.47,
          width: w * 1.45,
          height: 96,
          child: Transform.rotate(
            angle: 6 * pi / 180,
            child: const PaintReveal(delay: Duration(milliseconds: 140), duration: Duration(milliseconds: 150), fromRight: true, child: BrushShape(Brush.sweepLeft)),
          ),
        ),
        Positioned(
          left: -w * 0.15,
          top: h * 0.76,
          width: w * 1.36,
          height: 60,
          child: Transform.rotate(
            angle: -3 * pi / 180,
            child: const PaintReveal(delay: Duration(milliseconds: 220), duration: Duration(milliseconds: 140), child: BrushShape(Brush.thin, color: inkRed)),
          ),
        ),
        Positioned(
          left: -w * 0.2,
          top: -10,
          width: w * 1.4,
          height: h + 20,
          child: const InkDots(dots: [(0.03, 0.13, 4, false), (0.98, 0.22, 5, false), (0.93, 0.88, 3, true)]),
        ),
        Positioned.fill(
          child: PaintReveal(
            delay: const Duration(milliseconds: 340),
            duration: const Duration(milliseconds: 240),
            curve: const Cubic(0.8, 0, 0.2, 1),
            child: Transform.rotate(
              angle: -2 * pi / 180,
              child: DecoratedBox(
                decoration: const BoxDecoration(boxShadow: [BoxShadow(color: inkBlack, offset: Offset(9, 9))]),
                child: Container(
                  foregroundDecoration: BoxDecoration(border: Border.all(color: inkBlack, width: 3)),
                  child: CoverImage(url: cover, headers: headers, radius: 0, title: title),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

/// A manga's main character, inked black and white on a red sun, its left edge cut by a brush.
/// Painted in from the right. Sized for a 430 × 372 box.
class InkPortrait extends StatelessWidget {
  const InkPortrait({super.key, required this.mediaId});
  final int mediaId;

  static final _cache = <int, Future<(String, String)?>>{};

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(String, String)?>(
      future: _cache[mediaId] ??= Services.i.session.api.mainCharacter(mediaId).catchError((Object _) => null),
      builder: (context, snap) {
        final ch = snap.data;
        return Stack(children: [
          const Positioned(left: 30, top: 46, width: 250, height: 250, child: DecoratedBox(decoration: BoxDecoration(color: inkRed, shape: BoxShape.circle))),
          if (ch != null)
            Positioned(
              right: 0,
              top: 0,
              width: 400,
              height: 372,
              child: PaintReveal(
                delay: const Duration(milliseconds: 100),
                duration: const Duration(milliseconds: 500),
                fromRight: true,
                curve: const Cubic(0.8, 0, 0.2, 1),
                child: Stack(fit: StackFit.expand, children: [
                  ClipPath(
                    clipper: const _MaskClipper(),
                    child: ColorFiltered(
                      // Grayscale with strong contrast, like an ink print.
                      colorFilter: const ColorFilter.matrix([
                        0.42, 0.82, 0.14, 0, -95,
                        0.42, 0.82, 0.14, 0, -95,
                        0.42, 0.82, 0.14, 0, -95,
                        0, 0, 0, 1, 0,
                      ]),
                      child: Image.network(Net.image(ch.$2), fit: BoxFit.cover, alignment: const Alignment(0, -0.64)),
                    ),
                  ),
                  const BrushShape(Brush.portraitEdge),
                ]),
              ),
            ),
          if (ch != null && ch.$1.isNotEmpty) Positioned(right: 16, bottom: 14, child: InkTag(ch.$1)),
        ]);
      },
    );
  }
}

class _MaskClipper extends CustomClipper<Path> {
  const _MaskClipper();

  @override
  Path getClip(Size size) => scaledPath(portraitMask, const Size(400, 372), size);

  @override
  bool shouldReclip(_MaskClipper old) => false;
}

/// Ink blot with a source's initials (search and source cards).
class InitialsBlot extends StatelessWidget {
  const InitialsBlot({super.key, required this.name, this.size = 138, this.angle = 0});
  final String name;
  final double size;
  final double angle;

  static String initials(String name) {
    final words = name.replaceAll(RegExp(r'[^A-Za-z0-9 ]'), ' ').split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.length >= 2) return (words[0][0] + words[1][0]).toUpperCase();
    final w = words.firstOrNull ?? '?';
    final caps = w.split('').where((c) => c.toUpperCase() == c && RegExp(r'[A-Z]').hasMatch(c)).join();
    return (caps.length >= 2 ? caps.substring(0, 2) : w.substring(0, min(2, w.length))).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 0.9,
      child: Stack(alignment: Alignment.center, children: [
        Transform.rotate(angle: angle, child: InkBlot(width: size, height: size * 0.9)),
        Text(initials(name), style: GoogleFonts.notoSerifJp(fontSize: size * 0.26, fontWeight: FontWeight.w800, color: inkPaper, letterSpacing: 1)),
      ]),
    );
  }
}
/// Grayscale-with-contrast → full colour as [t] goes 0 → 1.
class Colorized extends StatelessWidget {
  const Colorized({required this.t, required this.child});
  final double t;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (t >= 1) return child;
    double l(double a, double b) => a + (b - a) * t;
    const g = [0.33, 0.65, 0.12];
    final m = <double>[
      l(g[0] * 1.5, 1), l(g[1] * 1.5, 0), l(g[2] * 1.5, 0), 0, l(-64, 0),
      l(g[0] * 1.5, 0), l(g[1] * 1.5, 1), l(g[2] * 1.5, 0), 0, l(-64, 0),
      l(g[0] * 1.5, 0), l(g[1] * 1.5, 0), l(g[2] * 1.5, 1), 0, l(-64, 0),
      0, 0, 0, 1, 0,
    ];
    return ColorFiltered(colorFilter: ColorFilter.matrix(m), child: child);
  }
}

