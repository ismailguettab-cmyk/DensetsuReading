import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

/// Motion language. Strong ease-out for anything entering, critically damped
/// springs for anything the finger touches, and nothing at all for keyboard actions.
class Motion {
  Motion._();

  static const easeOut = Cubic(0.23, 1, 0.32, 1);
  static const easeInOut = Cubic(0.77, 0, 0.175, 1);
  static const drawer = Cubic(0.32, 0.72, 0, 1);

  static const press = Duration(milliseconds: 110);
  static const fast = Duration(milliseconds: 180);
  static const base = Duration(milliseconds: 260);
  static const enter = Duration(milliseconds: 420);

  static bool reduced(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// Apple-style spring from a damping ratio and a response time (seconds).
  static SpringDescription spring({double damping = 1, double response = 0.35}) {
    final stiffness = (2 * 3.141592653589793 / response) * (2 * 3.141592653589793 / response);
    return SpringDescription.withDampingRatio(mass: 1, stiffness: stiffness, ratio: damping);
  }
}

/// Scales down the instant the pointer goes down (not on release), then springs
/// back with a hint of bounce. Works for any tappable surface.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.onTap, this.onLongPress, this.scale = 0.97, this.enabled = true});

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final bool enabled;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> with SingleTickerProviderStateMixin {
  late final _c = AnimationController.unbounded(vsync: this, value: 1);

  void _down() {
    if (!widget.enabled || Motion.reduced(context)) return;
    _c.animateTo(widget.scale, duration: Motion.press, curve: Motion.easeOut);
  }

  void _up() {
    if (Motion.reduced(context)) return;
    _c.animateWith(SpringSimulation(Motion.spring(damping: 0.72, response: 0.32), _c.value, 1, _c.velocity));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled && (widget.onTap != null || widget.onLongPress != null);
    return MouseRegion(
      cursor: active ? SystemMouseCursors.click : MouseCursor.defer,
      child: Listener(
        onPointerDown: active ? (_) => _down() : null,
        onPointerUp: active ? (_) => _up() : null,
        onPointerCancel: active ? (_) => _up() : null,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: active ? widget.onTap : null,
          onLongPress: active ? widget.onLongPress : null,
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, child) => Transform.scale(scale: _c.value, child: child),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Fades and lifts content in once, staggered by [index]. Purely decorative:
/// it never blocks input, and collapses to a plain fade when motion is reduced.
class Reveal extends StatefulWidget {
  const Reveal({super.key, required this.child, this.index = 0, this.offset = 14, this.step = 45});

  final Widget child;
  final int index;
  final double offset;
  final int step;

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: Motion.enter);
  late final _t = CurvedAnimation(parent: _c, curve: Motion.easeOut);

  @override
  void initState() {
    super.initState();
    final delay = Duration(milliseconds: (widget.index.clamp(0, 12)) * widget.step);
    Future.delayed(delay, () {
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
    // FadeTransition fades on the compositor; only the translate is rebuilt per frame.
    return FadeTransition(
      opacity: _t,
      child: reduced
          ? widget.child
          : AnimatedBuilder(
              animation: _t,
              builder: (_, child) => Transform.translate(offset: Offset(0, (1 - _t.value) * widget.offset), child: child),
              child: widget.child,
            ),
    );
  }
}

/// Mechanical counter: each digit is a 0–9 strip that rolls a full turn and lands
/// on its value, rightmost digit first. Replays (a quicker roll) when [replay] changes.
/// Only a translation is animated; the strips are clipped to one line.
class RollingNumber extends StatefulWidget {
  const RollingNumber({super.key, required this.value, required this.style, this.replay = 0});

  final int value;
  final TextStyle style;
  final int replay;

  @override
  State<RollingNumber> createState() => _RollingNumberState();
}

class _RollingNumberState extends State<RollingNumber> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void didUpdateWidget(RollingNumber old) {
    super.didUpdateWidget(old);
    if (old.replay != widget.replay || old.value != widget.value) {
      _c.duration = const Duration(milliseconds: 900);
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style.copyWith(height: 1);
    final digits = widget.value.toString().split('');
    if (Motion.reduced(context)) return Text(widget.value.toString(), style: style);
    final size = (TextPainter(text: TextSpan(text: '0', style: style), textDirection: TextDirection.ltr)..layout()).size;
    final line = size.height * 1.12;
    const curve = Cubic(0.16, 1, 0.3, 1);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < digits.length; i++) ...[
          if (i > 0 && (digits.length - i) % 3 == 0) SizedBox(width: size.width * 0.25),
          _strip(int.parse(digits[i]), digits.length - 1 - i, style, size.width, line, curve),
        ],
      ]),
    );
  }

  Widget _strip(int digit, int fromRight, TextStyle style, double width, double line, Curve curve) {
    final start = (fromRight * 0.07).clamp(0.0, 0.4);
    final t = curve.transform(((_c.value - start) / (1 - start)).clamp(0.0, 1.0));
    final travel = 10 + digit; // one full turn, then land on the digit
    return SizedBox(
      width: width,
      height: line,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topCenter,
          maxHeight: double.infinity,
          child: Transform.translate(
            offset: Offset(0, -travel * t * line),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              for (var n = 0; n < 20; n++)
                SizedBox(height: line, child: Center(child: Text('${n % 10}', style: style))),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Tilts its child in 3D toward the pointer (hover with a mouse, press with a finger),
/// on two independent springs so it settles naturally and can be interrupted.
/// Decorative only: transform, no layout.
class Tilt extends StatefulWidget {
  const Tilt({super.key, required this.child, this.maxAngle = 0.12, this.lift = 1.02});

  final Widget child;
  final double maxAngle; // radians
  final double lift; // scale while tilted

  @override
  State<Tilt> createState() => _TiltState();
}

class _TiltState extends State<Tilt> with TickerProviderStateMixin {
  late final _x = AnimationController.unbounded(vsync: this);
  late final _y = AnimationController.unbounded(vsync: this);
  late final _s = AnimationController.unbounded(vsync: this, value: 1);

  void _to(AnimationController c, double target, {double damping = 0.8}) =>
      c.animateWith(SpringSimulation(Motion.spring(damping: damping, response: 0.45), c.value, target, c.velocity));

  void _track(Offset local, Size size) {
    if (Motion.reduced(context) || size.isEmpty) return;
    final dx = (local.dx / size.width - 0.5) * 2;
    final dy = (local.dy / size.height - 0.5) * 2;
    _to(_y, dx.clamp(-1.0, 1.0) * widget.maxAngle);
    _to(_x, -dy.clamp(-1.0, 1.0) * widget.maxAngle);
    _to(_s, widget.lift, damping: 1);
  }

  void _release() {
    _to(_x, 0, damping: 0.7);
    _to(_y, 0, damping: 0.7);
    _to(_s, 1, damping: 0.9);
  }

  @override
  void dispose() {
    _x.dispose();
    _y.dispose();
    _s.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final size = Size(box.maxWidth.isFinite ? box.maxWidth : 0, box.maxHeight.isFinite ? box.maxHeight : 0);
      return MouseRegion(
        onHover: (e) => _track(e.localPosition, size),
        onExit: (_) => _release(),
        child: Listener(
          onPointerDown: (e) => _track(e.localPosition, size),
          onPointerMove: (e) => _track(e.localPosition, size),
          onPointerUp: (_) => _release(),
          onPointerCancel: (_) => _release(),
          child: AnimatedBuilder(
            animation: Listenable.merge([_x, _y, _s]),
            builder: (_, child) => Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0011)
                ..rotateX(_x.value)
                ..rotateY(_y.value)
                ..scaleByDouble(_s.value, _s.value, 1, 1),
              child: child,
            ),
            child: widget.child,
          ),
        ),
      );
    });
  }
}

/// Opens like a book cover hinged on its left edge, once, staggered by [index].
class BookUnfold extends StatefulWidget {
  const BookUnfold({super.key, required this.child, this.index = 0});

  final Widget child;
  final int index;

  @override
  State<BookUnfold> createState() => _BookUnfoldState();
}

class _BookUnfoldState extends State<BookUnfold> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 680));
  late final _t = CurvedAnimation(parent: _c, curve: const Cubic(0.16, 1, 0.3, 1));

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 70 * widget.index.clamp(0, 10)), () {
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
    if (Motion.reduced(context)) return FadeTransition(opacity: _t, child: widget.child);
    return FadeTransition(
      opacity: CurvedAnimation(parent: _c, curve: const Interval(0, 0.35)),
      child: AnimatedBuilder(
        animation: _t,
        builder: (_, child) => Transform(
          alignment: Alignment.centerLeft,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0014)
            ..rotateY((1 - _t.value) * -1.35),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

/// Counts up to [value] the first time it appears.
class CountUp extends StatelessWidget {
  const CountUp({super.key, required this.value, required this.style});

  final int value;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) return Text('$value', style: style);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 1100),
      curve: const Cubic(0.16, 1, 0.3, 1),
      builder: (_, v, __) => Text(_group(v.round()), style: style),
    );
  }

  static String _group(int n) {
    final s = n.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
      b.write(s[i]);
    }
    return b.toString();
  }
}
