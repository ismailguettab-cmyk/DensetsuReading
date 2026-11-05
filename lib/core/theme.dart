import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Colour tokens. Day mode is ink on cream paper with blood red kept for the one
/// action that matters on a screen; night mode keeps the earlier navy until it is redesigned.
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

  /// Day mode: cream paper, ink, blood red (see the style guide on the design canvas).
  static const light = Palette(
    bg: Color(0xFFF2EBDD),
    sidebar: Color(0xFFF2EBDD),
    surface: Color(0xFFFBF8F1),
    surface2: Color(0xFFEAE2D1),
    line: Color(0x2E121010),
    text: Color(0xFF121010),
    text2: Color(0xFF3B3633),
    text3: Color(0xFF5C554D),
    accent: Color(0xFF121010),
    accentSoft: Color(0x14121010),
    cta: Color(0xFFB5121B),
    onCta: Color(0xFFF2EBDD),
    star: Color(0xFFB5121B),
    danger: Color(0xFFB5121B),
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

/// Type scale: Noto Serif JP for titles and numbers (the "book" voice), Noto Sans JP
/// for everything you read or tap. Numbers use tabular figures so counters don't jitter.
class Txt {
  Txt._();

  static TextStyle _sans(Color c) => GoogleFonts.notoSansJp(color: c);
  static TextStyle _serif(Color c) => GoogleFonts.notoSerifJp(color: c);

  static TextStyle display(BuildContext c) =>
      _serif(c.pal.text).copyWith(fontSize: 48, fontWeight: FontWeight.w800, height: 1.0, letterSpacing: -1.0);
  static TextStyle h1(BuildContext c) =>
      _serif(c.pal.text).copyWith(fontSize: 28, fontWeight: FontWeight.w800, height: 1.1, letterSpacing: -0.5);
  static TextStyle h2(BuildContext c) =>
      _serif(c.pal.text).copyWith(fontSize: 22, fontWeight: FontWeight.w800, height: 1.2, letterSpacing: -0.2);
  static TextStyle title(BuildContext c) =>
      _sans(c.pal.text).copyWith(fontSize: 15, fontWeight: FontWeight.w700, height: 1.3);
  static TextStyle body(BuildContext c) =>
      _sans(c.pal.text2).copyWith(fontSize: 15, fontWeight: FontWeight.w400, height: 1.6);
  static TextStyle label(BuildContext c) =>
      _sans(c.pal.text).copyWith(fontSize: 14, fontWeight: FontWeight.w700, height: 1.2);
  static TextStyle caption(BuildContext c) =>
      _sans(c.pal.text3).copyWith(fontSize: 12.5, fontWeight: FontWeight.w500, height: 1.35);

  /// Small black tag in capitals, e.g. "REPRENDRE LA LECTURE".
  static TextStyle tag(BuildContext c) =>
      _sans(c.pal.text).copyWith(fontSize: 12, fontWeight: FontWeight.w900, height: 1.2, letterSpacing: 2);

  /// Kanji in the tabs and on stamps.
  static TextStyle kanji(BuildContext c, {double size = 24}) =>
      _serif(c.pal.text).copyWith(fontSize: size, fontWeight: FontWeight.w800, height: 1);

  static TextStyle number(BuildContext c, {double size = 28}) => _serif(c.pal.text).copyWith(
        fontSize: size,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.6,
        height: 1,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}

/// Day-mode shape language: square corners, 2 px ink borders, offset ink shadows.
class InkStyle {
  InkStyle._();

  static Border border(BuildContext c, {double width = 2}) => Border.all(color: c.pal.text, width: width);

  static List<BoxShadow> shadow(BuildContext c, {double offset = 5}) =>
      [BoxShadow(color: c.pal.text, offset: Offset(offset, offset))];

  static bool isDay(BuildContext c) => Theme.of(c).brightness == Brightness.light;
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
    textTheme: GoogleFonts.notoSansJpTextTheme(base.textTheme).apply(bodyColor: p.text, displayColor: p.text),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: p.line,
    dividerColor: p.line,
    iconTheme: IconThemeData(color: p.text2, size: 22),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: p.text),
      textStyle: GoogleFonts.notoSansJp(color: p.bg, fontSize: 12.5, fontWeight: FontWeight.w700),
      waitDuration: const Duration(milliseconds: 500),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: p.text,
      inactiveTrackColor: p.line,
      thumbColor: p.cta,
      overlayShape: SliderComponentShape.noOverlay,
      trackHeight: 4,
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
