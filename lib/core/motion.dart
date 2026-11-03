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
    return AnimatedBuilder(
      animation: _t,
      builder: (_, child) => Opacity(
        opacity: _t.value,
        child: Transform.translate(
          offset: Offset(0, reduced ? 0 : (1 - _t.value) * widget.offset),
          child: child,
        ),
      ),
      child: widget.child,
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
