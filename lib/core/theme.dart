import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Colour tokens. Ink-night navy with a calm periwinkle accent; the warm amber
/// is reserved for the one action that matters on a screen (read / continue).
@immutable
class Palette extends ThemeExtension<Palette> {
  const Palette({
    required this.bg,
    required this.sidebar,
    required this.surface,
    required this.surface2,
    required this.line,
    required this.text,
    required this.text2,
    required this.text3,
    required this.accent,
    required this.accentSoft,
    required this.cta,
    required this.onCta,
    required this.star,
    required this.danger,
  });

  final Color bg, sidebar, surface, surface2, line, text, text2, text3;
  final Color accent, accentSoft, cta, onCta, star, danger;

  static const dark = Palette(
    bg: Color(0xFF131623),
    sidebar: Color(0xFF181B2B),
    surface: Color(0xFF1D2134),
    surface2: Color(0xFF262B42),
    line: Color(0x14FFFFFF),
    text: Color(0xFFEDEEF6),
    text2: Color(0xFFA2A7BF),
    text3: Color(0xFF6E7493),
    accent: Color(0xFF9A97FF),
    accentSoft: Color(0x269A97FF),
    cta: Color(0xFFFFB25E),
    onCta: Color(0xFF2A1A08),
    star: Color(0xFFF6C657),
    danger: Color(0xFFFF7A7A),
  );

  static const light = Palette(
    bg: Color(0xFFF6F5F1),
    sidebar: Color(0xFFEEEDE7),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFEFEEE9),
    line: Color(0x14131623),
    text: Color(0xFF171A27),
    text2: Color(0xFF5B6075),
    text3: Color(0xFF8D91A3),
    accent: Color(0xFF5E58D6),
    accentSoft: Color(0x1F5E58D6),
    cta: Color(0xFFE88A2E),
    onCta: Color(0xFFFFFFFF),
    star: Color(0xFFDE9F12),
    danger: Color(0xFFD64545),
  );

  @override
  Palette copyWith() => this;

  @override
  Palette lerp(Palette? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return Palette(
      bg: l(bg, other.bg),
      sidebar: l(sidebar, other.sidebar),
      surface: l(surface, other.surface),
      surface2: l(surface2, other.surface2),
      line: l(line, other.line),
      text: l(text, other.text),
      text2: l(text2, other.text2),
      text3: l(text3, other.text3),
      accent: l(accent, other.accent),
      accentSoft: l(accentSoft, other.accentSoft),
      cta: l(cta, other.cta),
      onCta: l(onCta, other.onCta),
      star: l(star, other.star),
      danger: l(danger, other.danger),
    );
  }
}

extension PaletteX on BuildContext {
  Palette get pal => Theme.of(this).extension<Palette>()!;
}

/// Type scale: tight negative tracking on large text, neutral on body, a hair
/// positive on small captions. Numbers use tabular figures so counters don't jitter.
class Txt {
  Txt._();

  static TextStyle _base(Color c) => GoogleFonts.figtree(color: c);

  static TextStyle display(BuildContext c) =>
      _base(c.pal.text).copyWith(fontSize: 34, fontWeight: FontWeight.w700, height: 1.08, letterSpacing: -0.8);
  static TextStyle h1(BuildContext c) =>
      _base(c.pal.text).copyWith(fontSize: 26, fontWeight: FontWeight.w700, height: 1.15, letterSpacing: -0.5);
  static TextStyle h2(BuildContext c) =>
      _base(c.pal.text).copyWith(fontSize: 19, fontWeight: FontWeight.w700, height: 1.2, letterSpacing: -0.25);
  static TextStyle title(BuildContext c) =>
      _base(c.pal.text).copyWith(fontSize: 15, fontWeight: FontWeight.w600, height: 1.3, letterSpacing: -0.1);
  static TextStyle body(BuildContext c) =>
      _base(c.pal.text2).copyWith(fontSize: 14.5, fontWeight: FontWeight.w400, height: 1.6);
  static TextStyle label(BuildContext c) =>
      _base(c.pal.text).copyWith(fontSize: 13.5, fontWeight: FontWeight.w600, height: 1.2);
  static TextStyle caption(BuildContext c) =>
      _base(c.pal.text3).copyWith(fontSize: 12.5, fontWeight: FontWeight.w500, height: 1.35, letterSpacing: 0.1);
  static TextStyle number(BuildContext c, {double size = 28}) => _base(c.pal.text).copyWith(
        fontSize: size,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
        height: 1,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}

ThemeData buildTheme(Palette p, Brightness brightness) {
  final scheme = ColorScheme.fromSeed(seedColor: p.accent, brightness: brightness).copyWith(
    primary: p.accent,
    surface: p.surface,
    onSurface: p.text,
    error: p.danger,
  );
  final base = ThemeData(brightness: brightness, colorScheme: scheme, useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: p.bg,
    canvasColor: p.bg,
    textTheme: GoogleFonts.figtreeTextTheme(base.textTheme).apply(bodyColor: p.text, displayColor: p.text),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: p.line,
    dividerColor: p.line,
    iconTheme: IconThemeData(color: p.text2, size: 22),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(8)),
      textStyle: TextStyle(color: p.text, fontSize: 12.5),
      waitDuration: const Duration(milliseconds: 500),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: p.accent,
      inactiveTrackColor: p.surface2,
      thumbColor: p.text,
      overlayShape: SliderComponentShape.noOverlay,
      trackHeight: 3,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.bg : p.text3),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.accent : p.surface2),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    textSelectionTheme: TextSelectionThemeData(cursorColor: p.accent, selectionColor: p.accentSoft),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
    }),
    extensions: [p],
  );
}
