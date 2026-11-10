import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../anilist/anilist.dart';
import '../core/l10n.dart';
import '../core/motion.dart';
import '../core/platform.dart';
import '../core/services.dart';
import '../core/theme.dart';
import 'ink.dart';
import 'shell.dart';

/// Sign-in (day mode): a manga page of three panels on the left, the AniList card on the right.
/// One button signs in with AniList; a public username stays possible (read-only).
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _name = TextEditingController();
  bool _busy = false;
  bool _signingIn = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _anilist() async {
    final id = anilistClientId;
    if (id.isEmpty) {
      setState(() => _error = context.t('login.unavailable'));
      return;
    }
    setState(() {
      _signingIn = true;
      _error = null;
    });
    try {
      final token = await authorize(AniList.authorizeUrl(id));
      if (token != null && token.isNotEmpty) await Services.i.session.signInWithToken(token);
    } catch (_) {
      // Closed the AniList tab, or no network: stay here quietly.
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  Future<void> _username() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ok = await Services.i.session.signInWithUsername(name);
      if (!ok && mounted) setState(() => _error = context.t('login.notFound'));
    } catch (_) {
      if (mounted) setState(() => _error = context.t('login.error'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= 820;
    final safe = MediaQuery.paddingOf(context);
    final intro = _intro(context);
    final card = _card(context);
    return Scaffold(
      backgroundColor: inkPaper,
      body: wide
          ? Row(children: [
              Expanded(
                flex: 11,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(40 + safe.left, 36 + safe.top, 28, 36 + safe.bottom),
                  child: const _MangaWall(),
                ),
              ),
              Expanded(
                flex: 10,
                child: Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(28, 40 + safe.top, 48 + safe.right, 40 + safe.bottom),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [intro, const SizedBox(height: 30), card]),
                    ),
                  ),
                ),
              ),
            ])
          : SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(22, 22 + safe.top, 22, 40 + safe.bottom),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SizedBox(height: min(size.height * 0.42, 420), child: const _MangaWall()),
                    const SizedBox(height: 30),
                    intro,
                    const SizedBox(height: 26),
                    card,
                  ]),
                ),
              ),
            ),
    );
  }

  Widget _intro(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Reveal(child: BrandMark(size: 1.15, withName: true)),
      const SizedBox(height: 28),
      Reveal(index: 1, child: Text(context.t('login.title'), style: Txt.display(context).copyWith(fontSize: 56, height: 1.02))),
      const SizedBox(height: 14),
      Reveal(index: 2, child: Text(context.t('login.subtitle'), style: Txt.body(context).copyWith(fontSize: 16))),
    ]);
  }

  /// The paper card from the board: red brush button, then the read-only username option.
  Widget _card(BuildContext context) {
    final error = _error;
    return Reveal(
      index: 3,
      child: Container(
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
        decoration: const BoxDecoration(
          color: Color(0xFFFBF8F1),
          border: Border.fromBorderSide(BorderSide(color: inkBlack, width: 2)),
          boxShadow: [BoxShadow(color: inkBlack, offset: Offset(10, 10))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _BrushButton(label: context.t('login.anilist'), busy: _signingIn, onTap: _anilist),
          const SizedBox(height: 18),
          Row(children: [
            const Expanded(child: SizedBox(height: 2, child: ColoredBox(color: inkBlack))),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text(context.isEn ? 'or' : 'ou', style: Txt.caption(context))),
            const Expanded(child: SizedBox(height: 2, child: ColoredBox(color: inkBlack))),
          ]),
          const SizedBox(height: 16),
          Text(context.t('login.username'), style: Txt.label(context).copyWith(fontSize: 14)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _name,
                onSubmitted: (_) => _username(),
                style: Txt.label(context).copyWith(fontWeight: FontWeight.w500, fontSize: 15),
                decoration: InputDecoration(
                  hintText: context.t('login.usernameHint'),
                  hintStyle: Txt.label(context).copyWith(color: const Color(0xFF6B6359), fontWeight: FontWeight.w500, fontSize: 15),
                  filled: true,
                  fillColor: inkPaper,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
                  border: const OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: inkBlack, width: 2)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide(color: error != null && !_signingIn ? inkRed : inkBlack, width: 2),
                  ),
                  focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: inkRed, width: 2)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Pressable(
              onTap: _busy ? null : _username,
              child: Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                alignment: Alignment.center,
                color: inkBlack,
                child: _busy
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: inkPaper))
                    : Text(context.t('login.go'), style: Txt.label(context).copyWith(color: inkPaper, fontSize: 15)),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          if (error != null) ...[
            Text(error, style: Txt.label(context).copyWith(fontSize: 13, color: inkRed)),
            const SizedBox(height: 4),
          ],
          Text(context.t('login.usernameNote'), style: Txt.caption(context).copyWith(fontSize: 12)),
        ]),
      ),
    );
  }
}

/// The big red brush-stroke button ("Se connecter avec AniList").
class _BrushButton extends StatelessWidget {
  const _BrushButton({required this.label, required this.onTap, this.busy = false});
  final String label;
  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: busy ? null : onTap,
      child: SizedBox(
        height: 62,
        child: CustomPaint(
          painter: const _BrushButtonPainter(),
          child: Center(
            child: busy
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: inkPaper))
                : Text(label, style: Txt.label(context).copyWith(color: inkPaper, fontSize: 17, fontWeight: FontWeight.w900)),
          ),
        ),
      ),
    );
  }
}

class _BrushButtonPainter extends CustomPainter {
  const _BrushButtonPainter();
  static const _d = 'M6 12C40 2 150 0 214 8c6 14 6 32 0 42-60 8-160 8-208 0C0 38 0 22 6 12z';

  @override
  void paint(Canvas canvas, Size size) => canvas.drawPath(scaledPath(_d, const Size(220, 58), size), Paint()..color = inkRed);

  @override
  bool shouldRepaint(_BrushButtonPainter old) => false;
}

/// Three manga panels laid out like a page: a tall one on the left, two stacked on the
/// right, cut at a slant with thick ink borders and white gutters. Each panel is brushed
/// in, then the 伝説 seal lands on the corner.
class _MangaWall extends StatelessWidget {
  const _MangaWall();

  // Panel corners as fractions of the page (gutters included), slanted like a real page.
  static const _panels = [
    // Vegito, full height on the left.
    ('assets/login/planche1.jpg', Alignment(0, 0.45), [Offset(0, 0), Offset(0.47, 0), Offset(0.42, 1), Offset(0, 1)]),
    // Ichigo, wide, top right.
    ('assets/login/planche2.png', Alignment(-0.18, -0.35), [Offset(0.495, 0), Offset(1, 0), Offset(1, 0.53), Offset(0.48, 0.6)]),
    // Naruto, bottom right.
    ('assets/login/planche3.jpg', Alignment(0.25, -0.5), [Offset(0.475, 0.625), Offset(1, 0.555), Offset(1, 1), Offset(0.445, 1)]),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final s = Size(box.maxWidth, box.maxHeight);
      final dpr = MediaQuery.devicePixelRatioOf(context);
      return Stack(clipBehavior: Clip.none, children: [
        // The page itself: white paper, ink frame, offset shadow.
        Positioned.fill(
          child: Reveal(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border.fromBorderSide(BorderSide(color: inkBlack, width: 3)),
                boxShadow: [BoxShadow(color: inkBlack, offset: Offset(10, 10))],
              ),
            ),
          ),
        ),
        for (final (i, (asset, focus, corners)) in _panels.indexed)
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: LayoutBuilder(builder: (context, inner) {
                final pts = [for (final o in corners) Offset(o.dx * inner.maxWidth, o.dy * inner.maxHeight)];
                return PaintReveal(
                  delay: Duration(milliseconds: 220 + 160 * i),
                  duration: const Duration(milliseconds: 260),
                  fromRight: i == 1,
                  curve: const Cubic(0.8, 0, 0.2, 1),
                  child: Stack(fit: StackFit.expand, children: [
                    ClipPath(
                      clipper: _Poly(pts),
                      child: Image.asset(
                        asset,
                        fit: BoxFit.cover,
                        alignment: focus,
                        // Decode near the size shown: the first page is big.
                        cacheWidth: (max(s.width, s.height) * dpr).round(),
                        filterQuality: FilterQuality.medium,
                        // Each picture covers only its panel's bounds.
                        frameBuilder: (context, child, _, _) => _PanelBounds(points: pts, child: child),
                      ),
                    ),
                    IgnorePointer(child: CustomPaint(painter: _PolyBorder(pts))),
                  ]),
                );
              }),
            ),
          ),
        // Red seal on the page corner.
        Positioned(
          right: -18,
          bottom: 26,
          child: HankoStamp(text: '伝説', size: 86, delay: const Duration(milliseconds: 950), caption: 'DENSETSU'),
        ),
        // Title strip, like a chapter header.
        Positioned(
          left: -10,
          top: 30,
          child: OneShot(
            delay: const Duration(milliseconds: 800),
            duration: const Duration(milliseconds: 380),
            builder: (context, t, child) => Opacity(
              opacity: t,
              child: Transform.translate(offset: Offset(-24 * (1 - Motion.easeOut.transform(t)), 0), child: child),
            ),
            child: Transform.rotate(
              angle: -3 * pi / 180,
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 6, 16, 8),
                decoration: const BoxDecoration(color: inkBlack, boxShadow: [BoxShadow(color: inkRed, offset: Offset(5, 5))]),
                child: Text('MANGA · MANHWA · WEBTOON', style: GoogleFonts.notoSansJp(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2, color: inkPaper)),
              ),
            ),
          ),
        ),
      ]);
    });
  }
}

/// Places a picture over the bounding box of its panel only (so "cover" frames the panel).
class _PanelBounds extends StatelessWidget {
  const _PanelBounds({required this.points, required this.child});
  final List<Offset> points;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final left = points.map((o) => o.dx).reduce(min), right = points.map((o) => o.dx).reduce(max);
    final top = points.map((o) => o.dy).reduce(min), bottom = points.map((o) => o.dy).reduce(max);
    return Stack(children: [Positioned(left: left, top: top, width: right - left, height: bottom - top, child: child)]);
  }
}

class _Poly extends CustomClipper<Path> {
  _Poly(this.points);
  final List<Offset> points;

  @override
  Path getClip(Size size) => Path()..addPolygon(points, true);

  @override
  bool shouldReclip(_Poly old) => old.points != points;
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
          ..strokeWidth = 3.5
          ..strokeJoin = StrokeJoin.miter,
      );

  @override
  bool shouldRepaint(_PolyBorder old) => old.points != points;
}
