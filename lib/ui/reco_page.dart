import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../anilist/recommender.dart';
import '../core/l10n.dart';
import '../core/motion.dart';
import '../core/services.dart';
import '../core/theme.dart';
import 'ink.dart';
import 'reco_book.dart';
import 'reco_symbols.dart';
import 'widgets.dart';

/// Recommendations (day mode): every category is a book on the shelves. The planks are
/// brushed in, the books drop onto them one by one and settle; "Reload" sweeps ink over
/// the shelves and the new books appear as it leaves. The entrance replays on each visit.
class RecoPage extends StatefulWidget {
  const RecoPage({super.key});

  @override
  State<RecoPage> createState() => _RecoPageState();
}

class _RecoPageState extends State<RecoPage> {
  @override
  void initState() {
    super.initState();
    Services.i.reco.onVisit();
  }

  @override
  Widget build(BuildContext context) {
    final reco = Services.i.reco;
    return Scaffold(
      body: ListenableBuilder(
        listenable: reco,
        builder: (context, _) => LayoutBuilder(builder: (context, box) {
          final wide = box.maxWidth >= 900;
          final pad = wide ? 48.0 : 22.0;
          final rows = reco.rows;
          return ListView(padding: EdgeInsets.fromLTRB(0, wide ? 34 : 28, 0, wide ? 40 : 120), children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: pad),
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Reveal(child: Text(context.t('reco.title'), style: Txt.display(context).copyWith(fontSize: wide ? 54 : 42))),
                    const SizedBox(height: 8),
                    Reveal(
                      index: 1,
                      child: Text(
                        context.isEn ? 'Your shelves, picked from your tastes. Tap a book to open it.' : 'Tes rayons, choisis selon tes goûts. Touche un livre pour l’ouvrir.',
                        style: Txt.body(context).copyWith(fontSize: 16),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(width: 16),
                Reveal(index: 2, child: _ReloadButton(busy: reco.loading, onTap: reco.draw)),
              ]),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(pad, 18, pad, 6),
              child: const SizedBox(height: 18, child: PaintReveal(delay: Duration(milliseconds: 120), duration: Duration(milliseconds: 300), child: BrushShape(Brush.divider))),
            ),
            if (reco.error != null && rows.isEmpty)
              Padding(
                padding: const EdgeInsets.all(40),
                child: EmptyState(
                  icon: Icons.wifi_off_rounded,
                  title: context.t('reco.error'),
                  action: AppButton(label: context.t('detail.retry'), tone: ButtonTone.quiet, onTap: reco.draw),
                ),
              )
            else if (rows.isEmpty)
              Padding(padding: const EdgeInsets.all(60), child: Center(child: Text(context.t('reco.loading'), style: Txt.caption(context))))
            else
              InkReload(
                busy: reco.loading,
                child: _Shelves(key: ValueKey(reco.drawnAt), rows: rows, pad: pad, width: box.maxWidth),
              ),
          ]);
        }),
      ),
    );
  }
}

/// The books spread over as many shelves as the width needs (no sideways scrolling).
class _Shelves extends StatelessWidget {
  const _Shelves({super.key, required this.rows, required this.pad, required this.width});
  final List<RecoRow> rows;
  final double pad, width;

  static const _bookW = 148.0, _gap = 24.0;

  /// (book, ink, spine) as on the board: the first book red, then paper and ink alternately.
  static (Color, Color, Color) look(int i) => i == 0
      ? (inkRed, inkPaper, inkBlack)
      : i.isOdd
          ? (const Color(0xFFFBF8F1), inkBlack, inkBlack)
          : (inkBlack, inkPaper, inkRed);

  @override
  Widget build(BuildContext context) {
    final perShelf = max(2, ((width - 2 * pad + _gap) / (_bookW + _gap)).floor());
    final shelves = <List<int>>[
      for (var start = 0; start < rows.length; start += perShelf) [for (var i = start; i < min(start + perShelf, rows.length); i++) i],
    ];
    return Column(children: [
      for (final (s, books) in shelves.indexed)
        Padding(
          padding: EdgeInsets.fromLTRB(pad, 22, pad, 6),
          child: _Shelf(shelfIndex: s, children: [
            for (final (k, i) in books.indexed)
              _DropIn(
                // Shelf after shelf, book after book (45 ms apart), each landing with a little tilt.
                delay: Duration(milliseconds: 260 + s * 180 + k * 45),
                tilt: (i.isEven ? -1 : 1) * (2.0 + (i * 7 % 3)),
                // Underlines in reading order, quick (50 ms apart, 160 ms each) once the books have landed.
                child: _Book(row: rows[i], look: look(i), underlineDelay: Duration(milliseconds: 620 + 50 * i)),
              ),
          ]),
        ),
    ]);
  }
}

/// A plank brushed in under its row of books.
class _Shelf extends StatelessWidget {
  const _Shelf({required this.shelfIndex, required this.children});
  final int shelfIndex;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(
        height: 226,
        child: Align(
          alignment: Alignment.bottomLeft,
          child: Wrap(spacing: _Shelves._gap, crossAxisAlignment: WrapCrossAlignment.end, children: children),
        ),
      ),
      PaintReveal(
        delay: Duration(milliseconds: 140 + shelfIndex * 180),
        duration: const Duration(milliseconds: 260),
        curve: const Cubic(0.8, 0, 0.2, 1),
        child: const SizedBox(height: 16, child: BrushShape(Brush.plank)),
      ),
    ]);
  }
}

/// Falls from above onto the plank, overshoots a touch, and rocks from [tilt]° back to
/// upright. One controller per book, transform and opacity only, never blocks taps.
class _DropIn extends StatelessWidget {
  const _DropIn({required this.delay, required this.tilt, required this.child});
  final Duration delay;
  final double tilt;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return OneShot(
      delay: delay,
      duration: const Duration(milliseconds: 560),
      builder: (context, t, child) {
        final fall = const Cubic(0.3, 1.35, 0.5, 1).transform((t / 0.55).clamp(0.0, 1.0));
        // After landing, a damped rock: tilt → −tilt/3 → 0.
        final rock = t < 0.4 ? 1.0 : (1 - (t - 0.4) / 0.6) * cos((t - 0.4) / 0.6 * pi * 1.5);
        return Opacity(
          opacity: (t / 0.25).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, -46 * (1 - fall)),
            child: Transform.rotate(angle: tilt * rock * pi / 180, alignment: Alignment.bottomCenter, child: child),
          ),
        );
      },
      child: RepaintBoundary(child: child),
    );
  }
}

/// The category's figure in ink on the book: three characters for shōnen / seinen / josei,
/// a symbol for the others (from the "Reco" board).
class BookArt extends StatelessWidget {
  const BookArt({super.key, required this.category, required this.ink, required this.paper, this.scale = 1});
  final String category;
  final Color ink, paper;
  final double scale;

  @override
  Widget build(BuildContext context) {
    if (category == 'jump') {
      // Shōnen Jump: its shout in comic lettering, ink outline over the book colour.
      return SizedBox(
        width: 120 * scale,
        height: 96 * scale,
        child: Center(
          child: Transform.rotate(
            angle: -8 * pi / 180,
            child: Text('JUMP!', style: GoogleFonts.bangers(fontSize: 46 * scale, color: ink, letterSpacing: 1, height: 1)),
          ),
        ),
      );
    }
    final trio = bookTrios[category];
    final parts = trio ?? bookSymbols[category] ?? bookSymbols['forYou']!;
    final box = trio != null ? const Size(200, 150) : const Size(100, 100);
    final size = trio != null ? Size(140 * scale, 105 * scale) : Size(96 * scale, 96 * scale);
    return CustomPaint(size: size, painter: _BookArtPainter(parts, box, ink, paper));
  }
}

class _BookArtPainter extends CustomPainter {
  _BookArtPainter(this.parts, this.viewBox, this.ink, this.paper);
  final List<BookPart> parts;
  final Size viewBox;
  final Color ink, paper;

  @override
  void paint(Canvas canvas, Size size) {
    for (final (filled, d, evenOdd) in parts) {
      final path = scaledPath(d, viewBox, size);
      if (evenOdd) path.fillType = PathFillType.evenOdd;
      canvas.drawPath(path, Paint()..color = filled ? ink : paper);
    }
  }

  @override
  bool shouldRepaint(_BookArtPainter old) => old.parts != parts || old.ink != ink || old.paper != paper;
}

/// Brush-lettered title: the stroke under it sweeps in left to right, then two drops pop
/// at its end. Clip and scale only.
class _InkTitle extends StatelessWidget {
  const _InkTitle({required this.text, required this.ink, required this.drop, required this.delay});
  final String text;
  final Color ink, drop;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(text, softWrap: false, textAlign: TextAlign.center, style: GoogleFonts.notoSerifJp(fontSize: 20, fontWeight: FontWeight.w800, color: ink, height: 1.05)),
      ),
      const SizedBox(height: 3),
      SizedBox(
        width: 104,
        height: 14,
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned.fill(
            child: PaintReveal(
              delay: delay,
              duration: const Duration(milliseconds: 160),
              curve: const Cubic(0.9, 0, 0.3, 1),
              child: BrushShape(Brush.underline, color: ink),
            ),
          ),
          Positioned.fill(
            child: InkDots(
              delay: delay + const Duration(milliseconds: 130),
              dots: [(1.04, 0.35, 3, drop == inkRed), (0.92, 1.05, 2, drop == inkRed)],
            ),
          ),
        ]),
      ),
    ]);
  }
}

/// A category book. Hover lifts it; a tap pulls it off the shelf (up and tilted) before
/// the ink bursts into the book.
class _Book extends StatefulWidget {
  const _Book({required this.row, required this.look, required this.underlineDelay});
  final RecoRow row;
  final (Color, Color, Color) look;
  final Duration underlineDelay;

  @override
  State<_Book> createState() => _BookState();
}

class _BookState extends State<_Book> with SingleTickerProviderStateMixin {
  bool _hover = false;
  late final _pull = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));

  @override
  void dispose() {
    _pull.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    if (_pull.isAnimating) return;
    if (!Motion.reduced(context)) await _pull.forward(from: 0);
    if (!mounted) return;
    await Navigator.of(context).push(InkBurstRoute(RecoBookPage(rowKey: widget.row.key)));
    if (mounted) _pull.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final (bg, fg, spine) = widget.look;
    final row = widget.row;
    final trio = bookTrios.containsKey(row.key);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Pressable(
        onTap: _open,
        child: AnimatedBuilder(
          animation: _pull,
          builder: (context, child) {
            final t = Motion.easeOut.transform(_pull.value);
            final lift = _hover ? -8.0 : 0.0;
            return Transform.translate(
              offset: Offset(0, lift - 26 * t),
              child: Transform.rotate(angle: (_hover ? -1.5 : 0) * pi / 180 - 5 * t * pi / 180, alignment: Alignment.bottomLeft, child: child),
            );
          },
          child: Container(
            width: _Shelves._bookW,
            height: 212,
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              color: bg,
              border: Border.all(color: inkBlack, width: 2),
              boxShadow: const [BoxShadow(color: inkBlack, offset: Offset(6, 6))],
            ),
            child: Stack(children: [
              Positioned(left: 0, top: 0, bottom: 0, width: 12, child: ColoredBox(color: spine)),
              // The category name, centred and slightly tilted, underlined by a brush stroke
              // that draws itself (shelf after shelf, book after book) with two ink drops.
              Positioned(
                left: 16,
                right: 6,
                top: 14,
                child: Transform.rotate(
                  angle: -4 * pi / 180,
                  child: _InkTitle(text: context.isEn ? row.labelEn : row.labelFr, ink: fg, drop: spine == inkRed ? inkRed : (bg == inkRed ? inkBlack : inkRed), delay: widget.underlineDelay),
                ),
              ),
              Positioned(left: trio ? 10 : 30, bottom: trio ? -2 : 18, child: BookArt(category: row.key, ink: fg, paper: bg)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// "Reload": a square ink button that draws a whole new set of suggestions.
class _ReloadButton extends StatelessWidget {
  const _ReloadButton({required this.busy, required this.onTap});
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: busy ? null : onTap,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: const BoxDecoration(color: inkBlack, boxShadow: [BoxShadow(color: inkRed, offset: Offset(4, 4))]),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          busy
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: inkPaper))
              : const Icon(Icons.refresh_rounded, size: 18, color: inkPaper),
          const SizedBox(width: 8),
          Text(context.isEn ? 'Reload' : 'Recharger', style: Txt.label(context).copyWith(color: inkPaper, fontSize: 14)),
        ]),
      ),
    );
  }
}
