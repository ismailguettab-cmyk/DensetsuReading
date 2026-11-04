import 'dart:math';

import 'package:flutter/material.dart';

import '../core/motion.dart';

/// A light gust of cherry blossom petals across the screen when a page opens.
/// Ten petals, one pass, never blocks input, and nothing at all with reduced motion.
class SakuraBurst {
  SakuraBurst._();

  static void play(OverlayState overlay) {
    if (Motion.reduced(overlay.context)) return;
    late OverlayEntry entry;
    entry = OverlayEntry(builder: (_) => _Gust(onDone: () => entry.remove()));
    overlay.insert(entry);
  }
}

class _Petal {
  _Petal(Random r)
      : x = 0.35 + r.nextDouble() * 0.8,
        y = -0.12 - r.nextDouble() * 0.25,
        drift = 0.55 + r.nextDouble() * 0.45,
        fall = 0.75 + r.nextDouble() * 0.5,
        size = 7 + r.nextDouble() * 7,
        spin = (r.nextBool() ? 1 : -1) * (2 + r.nextDouble() * 3),
        sway = r.nextDouble() * pi * 2,
        delay = r.nextDouble() * 0.25,
        tint = r.nextDouble();

  final double x, y, drift, fall, size, spin, sway, delay, tint;
}

class _Gust extends StatefulWidget {
  const _Gust({required this.onDone});
  final VoidCallback onDone;

  @override
  State<_Gust> createState() => _GustState();
}

class _GustState extends State<_Gust> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    })
    ..forward();
  final _petals = List.generate(10, (_) => _Petal(Random()));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: RepaintBoundary(child: CustomPaint(painter: _PetalPainter(_c, _petals), size: Size.infinite)),
      );
}

class _PetalPainter extends CustomPainter {
  _PetalPainter(this.t, this.petals) : super(repaint: t);
  final Animation<double> t;
  final List<_Petal> petals;

  static final _shape = Path()
    ..moveTo(0, -1)
    ..cubicTo(0.75, -0.9, 0.9, 0.2, 0, 1)
    ..cubicTo(-0.9, 0.2, -0.75, -0.9, -0.12, -0.92)
    ..lineTo(0, -0.7)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in petals) {
      final v = ((t.value - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (v <= 0) continue;
      final e = Curves.easeOutSine.transform(v);
      final dx = (p.x - e * p.drift) * size.width + sin(p.sway + v * 5) * 18;
      final dy = (p.y + e * p.fall) * size.height;
      final alpha = (v < 0.15 ? v / 0.15 : (v > 0.7 ? (1 - v) / 0.3 : 1.0)) * 0.85;
      final color = Color.lerp(const Color(0xFFF8C8D4), const Color(0xFFFFE4EA), p.tint)!.withValues(alpha: alpha);
      canvas
        ..save()
        ..translate(dx, dy)
        ..rotate(p.spin * v)
        ..scale(p.size, p.size * 0.82);
      canvas.drawPath(_shape, Paint()..color = color);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_PetalPainter old) => false;
}
