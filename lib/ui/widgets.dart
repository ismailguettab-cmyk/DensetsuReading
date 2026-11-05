import 'package:flutter/material.dart';

import '../core/motion.dart';
import '../core/net.dart';
import '../core/theme.dart';
import '../sources/source.dart';
import 'sakura.dart';

/// Cover art that fades in once decoded, with a quiet placeholder meanwhile.
class CoverImage extends StatelessWidget {
  const CoverImage({super.key, required this.url, this.headers = const {}, this.radius = 0, this.heroTag, this.title});

  final String? url;
  final Map<String, String> headers;
  final double radius;
  final Object? heroTag;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final placeholder = Container(
      color: p.surface2,
      alignment: Alignment.center,
      child: title == null
          ? null
          : Padding(
              padding: const EdgeInsets.all(10),
              child: Text(title!, textAlign: TextAlign.center, maxLines: 4, overflow: TextOverflow.ellipsis, style: Txt.caption(context)),
            ),
    );
    Widget image = url == null
        ? placeholder
        : Image.network(
            Net.image(url!, headers),
            headers: Net.nativeHeaders(url!, headers),
            fit: BoxFit.cover,
            gaplessPlayback: true,
            frameBuilder: (context, child, frame, sync) {
              if (sync) return child;
              return Stack(fit: StackFit.expand, children: [
                placeholder,
                AnimatedOpacity(
                  opacity: frame == null ? 0 : 1,
                  duration: Motion.base,
                  curve: Motion.easeOut,
                  child: child,
                ),
              ]);
            },
            errorBuilder: (_, __, ___) => placeholder,
          );
    image = ClipRRect(borderRadius: BorderRadius.circular(radius), child: SizedBox.expand(child: image));
    if (heroTag != null) image = Hero(tag: heroTag!, child: image);
    return image;
  }
}

/// Cover + two lines of text. The whole card scales on press.
class MangaCard extends StatelessWidget {
  const MangaCard({
    super.key,
    required this.title,
    required this.cover,
    this.subtitle,
    this.headers = const {},
    this.onTap,
    this.heroTag,
    this.width = 148,
    this.badge,
  });

  final String title;
  final String? cover;
  final String? subtitle;
  final Map<String, String> headers;
  final VoidCallback? onTap;
  final Object? heroTag;
  final double width;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 2 / 3,
              child: DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: BoxDecoration(border: InkStyle.border(context)),
                child: Stack(fit: StackFit.expand, children: [
                  CoverImage(url: cover, headers: headers, heroTag: heroTag, title: title),
                  if (badge != null) Positioned(left: 8, top: 8, child: badge!),
                ]),
              ),
            ),
            const SizedBox(height: 10),
            Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Txt.title(context).copyWith(fontSize: 14)),
            if (subtitle != null) ...[
              const SizedBox(height: 3),
              Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: Txt.caption(context)),
            ],
          ],
        ),
      ),
    );
  }
}

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.color, this.textColor, this.icon});

  final String text;
  final Color? color, textColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color, border: InkStyle.border(context)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 13, color: textColor ?? p.text), const SizedBox(width: 5)],
        Text(text, style: Txt.caption(context).copyWith(color: textColor ?? p.text, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

enum ButtonTone { cta, accent, quiet }

class AppButton extends StatelessWidget {
  const AppButton({super.key, required this.label, this.icon, this.onTap, this.tone = ButtonTone.cta, this.loading = false, this.expand = false});

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final ButtonTone tone;
  final bool loading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    // Red for the one action that matters, ink for the rest, an ink outline for quiet ones.
    final (bg, fg) = switch (tone) {
      ButtonTone.cta => (p.cta, p.onCta),
      ButtonTone.accent => (p.text, p.bg),
      ButtonTone.quiet => (Colors.transparent, p.text),
    };
    final enabled = onTap != null && !loading;
    return Pressable(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        opacity: onTap == null ? 0.45 : 1,
        duration: Motion.fast,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(color: bg, border: tone == ButtonTone.quiet ? InkStyle.border(context) : null),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading)
                SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
              else if (icon != null)
                Icon(icon, size: 19, color: fg),
              if (loading || icon != null) const SizedBox(width: 9),
              Flexible(
                child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Txt.label(context).copyWith(color: fg, fontSize: 14.5)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class IconCircle extends StatelessWidget {
  const IconCircle({super.key, required this.icon, this.onTap, this.tooltip, this.active = false, this.size = 42});

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final bool active;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final button = Pressable(
      onTap: onTap,
      scale: 0.92,
      child: AnimatedContainer(
        duration: Motion.fast,
        width: size,
        height: size,
        decoration: BoxDecoration(color: active ? p.text : Colors.transparent, shape: BoxShape.circle, border: InkStyle.border(context)),
        child: Icon(icon, size: size * 0.46, color: active ? p.bg : p.text),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(children: [
        Text(text, style: Txt.h2(context)),
        const SizedBox(width: 14),
        // An ink rule runs from the title to the edge, like a chapter heading.
        Expanded(child: Container(height: 2, color: context.pal.text)),
        if (trailing != null) ...[const SizedBox(width: 14), trailing!],
      ]),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.text, this.action});

  final IconData icon;
  final String title;
  final String? text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          InkBlot(width: 96, height: 86, child: Icon(icon, color: p.bg, size: 34)),
          const SizedBox(height: 18),
          Text(title, textAlign: TextAlign.center, style: Txt.h2(context)),
          if (text != null) ...[
            const SizedBox(height: 8),
            Text(text!, textAlign: TextAlign.center, style: Txt.body(context)),
          ],
          if (action != null) ...[const SizedBox(height: 22), action!],
        ]),
      ),
    );
  }
}

/// Source logo (site favicon), with a monogram while it loads or if it fails.
class SourceLogo extends StatelessWidget {
  const SourceLogo(this.source, {super.key, this.size = 44});

  final MangaSource source;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final monogram = Container(
      color: p.surface2,
      alignment: Alignment.center,
      child: Text(source.name.characters.first, style: Txt.h2(context).copyWith(fontSize: size * 0.42, color: p.accent)),
    );
    return ClipRect(
      child: SizedBox(
        width: size,
        height: size,
        child: Container(
          decoration: BoxDecoration(color: p.surface, border: InkStyle.border(context)),
          padding: EdgeInsets.all(size * 0.18),
          child: Image.network(
            Net.image(source.iconUrl),
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => monogram,
            frameBuilder: (_, child, frame, sync) => sync || frame != null ? child : const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

/// Quiet loading block.
class Skeleton extends StatelessWidget {
  const Skeleton({super.key, this.width, this.height, this.radius = 0});

  final double? width, height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(color: context.pal.surface2.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(radius)),
      );
}

/// Surface for floating chrome (reader bars, portrait tab bar).
class Glass extends StatelessWidget {
  const Glass({super.key, required this.child, this.radius = 18, this.tint, this.padding});

  final Widget child;
  final double radius;
  final Color? tint;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    // Paper panel with an ink border and an offset ink shadow (no blur in the ink design).
    return Container(
      padding: padding,
      decoration: BoxDecoration(color: tint ?? p.bg, border: InkStyle.border(context), boxShadow: InkStyle.shadow(context)),
      child: child,
    );
  }
}

/// Segmented choice with a sliding selection (spring-free: a short ease-out).
class Segmented<T> extends StatelessWidget {
  const Segmented({super.key, required this.value, required this.options, required this.onChanged});

  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final index = options.indexWhere((o) => o.$1 == value).clamp(0, options.length - 1);
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth.isFinite ? box.maxWidth : options.length * 110.0;
      final segment = (w - 4) / options.length;
      return Container(
        width: w,
        height: 42,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(border: InkStyle.border(context)),
        child: Stack(children: [
          AnimatedPositioned(
            duration: Motion.base,
            curve: Motion.easeOut,
            left: index * segment,
            top: 0,
            bottom: 0,
            width: segment,
            child: ColoredBox(color: p.text),
          ),
          Row(children: [
            for (final o in options)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(o.$1),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Center(
                      child: Text(
                        o.$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Txt.label(context).copyWith(fontSize: 13, color: o.$1 == value ? p.bg : p.text),
                      ),
                    ),
                  ),
                ),
              ),
          ]),
        ]),
      );
    });
  }
}

/// Fade + slight scale route, used for detail pages (the cover flies with a Hero).
class SoftRoute<T> extends PageRouteBuilder<T> {
  SoftRoute(Widget page)
      : super(
          transitionDuration: const Duration(milliseconds: 380),
          reverseTransitionDuration: const Duration(milliseconds: 260),
          pageBuilder: (_, __, ___) => page,
          transitionsBuilder: (context, animation, secondary, child) {
            final t = CurvedAnimation(parent: animation, curve: Motion.easeOut, reverseCurve: Curves.easeIn);
            final reduced = Motion.reduced(context);
            return FadeTransition(
              opacity: t,
              child: reduced ? child : ScaleTransition(scale: Tween(begin: 0.985, end: 1.0).animate(t), child: child),
            );
          },
        );

  @override
  TickerFuture didPush() {
    final overlay = navigator?.overlay;
    // Petals belong to the night theme; the day theme stays ink and paper.
    if (overlay != null && Theme.of(overlay.context).brightness == Brightness.dark) SakuraBurst.play(overlay);
    return super.didPush();
  }
}

void toast(BuildContext context, String message) {
  final p = context.pal;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message, style: Txt.label(context).copyWith(color: p.bg)),
      backgroundColor: p.text,
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(),
      width: 420,
      duration: const Duration(seconds: 3),
    ));
}

/// Ink blot: the active tab, source seals and empty states sit on this shape.
class InkBlot extends StatelessWidget {
  const InkBlot({super.key, this.width = 64, this.height = 58, this.color, this.dot, this.child});

  final double width, height;
  final Color? color;

  /// Optional small drop in the top-right corner (blood red on the active tab).
  final Color? dot;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _InkBlotPainter(color ?? context.pal.text, dot),
        child: child == null ? null : Center(child: child),
      ),
    );
  }
}

class _InkBlotPainter extends CustomPainter {
  _InkBlotPainter(this.color, this.dot);

  final Color color;
  final Color? dot;

  @override
  void paint(Canvas canvas, Size size) {
    // Drawn in a 64 x 58 box (the shape used on the design canvas), then stretched to fit.
    canvas.scale(size.width / 64, size.height / 58);
    final ink = Paint()..color = color;
    final blot = Path()
      ..moveTo(10, 14)
      ..cubicTo(18, 3, 44, 1, 55, 9)
      ..cubicTo(64, 16, 63, 35, 54, 44)
      ..cubicTo(44, 54, 21, 57, 10, 48)
      ..cubicTo(1, 41, 3, 23, 10, 14)
      ..close();
    canvas.drawPath(blot, ink);
    canvas.drawCircle(const Offset(58, 50), 2.6, ink);
    canvas.drawCircle(const Offset(5, 8), 1.8, ink);
    if (dot != null) canvas.drawCircle(const Offset(52, 10), 4, Paint()..color = dot!);
  }

  @override
  bool shouldRepaint(_InkBlotPainter old) => old.color != color || old.dot != dot;
}
