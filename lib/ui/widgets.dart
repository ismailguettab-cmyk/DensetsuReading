import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/motion.dart';
import '../core/net.dart';
import '../core/theme.dart';
import '../sources/source.dart';

/// Cover art that fades in once decoded, with a quiet placeholder meanwhile.
class CoverImage extends StatelessWidget {
  const CoverImage({super.key, required this.url, this.headers = const {}, this.radius = 12, this.heroTag, this.title});

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
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 18, offset: Offset(0, 8))],
                ),
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
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(color: color ?? p.accentSoft, borderRadius: BorderRadius.circular(99)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 13, color: textColor ?? p.accent), const SizedBox(width: 5)],
        Text(text, style: Txt.caption(context).copyWith(color: textColor ?? p.accent, fontWeight: FontWeight.w600)),
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
    final (bg, fg) = switch (tone) {
      ButtonTone.cta => (p.cta, p.onCta),
      ButtonTone.accent => (p.accent, p.bg),
      ButtonTone.quiet => (p.surface2, p.text),
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
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
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
        decoration: BoxDecoration(color: active ? p.accent : p.surface2, shape: BoxShape.circle),
        child: Icon(icon, size: size * 0.48, color: active ? p.bg : p.text),
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
        Expanded(child: Text(text, style: Txt.h2(context))),
        ?trailing,
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
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: p.accentSoft, borderRadius: BorderRadius.circular(20)),
            child: Icon(icon, color: p.accent, size: 28),
          ),
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.28),
      child: SizedBox(
        width: size,
        height: size,
        child: Container(
          color: p.surface2,
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
  const Skeleton({super.key, this.width, this.height, this.radius = 12});

  final double? width, height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(color: context.pal.surface2.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(radius)),
      );
}

/// Frosted surface for floating chrome. Only used on bars that stay put.
class Glass extends StatelessWidget {
  const Glass({super.key, required this.child, this.radius = 18, this.tint, this.padding});

  final Widget child;
  final double radius;
  final Color? tint;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: (tint ?? p.surface).withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: p.line),
          ),
          child: child,
        ),
      ),
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
      final segment = (w - 8) / options.length;
      return Container(
        width: w,
        height: 40,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(12)),
        child: Stack(children: [
          AnimatedPositioned(
            duration: Motion.base,
            curve: Motion.easeOut,
            left: index * segment,
            top: 0,
            bottom: 0,
            width: segment,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(9),
                boxShadow: const [BoxShadow(color: Color(0x26000000), blurRadius: 6, offset: Offset(0, 2))],
              ),
            ),
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
                        style: Txt.label(context).copyWith(fontSize: 13, color: o.$1 == value ? p.text : p.text2),
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
}

void toast(BuildContext context, String message) {
  final p = context.pal;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message, style: Txt.label(context)),
      backgroundColor: p.surface2,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      width: 420,
      duration: const Duration(seconds: 3),
    ));
}
