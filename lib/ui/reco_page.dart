import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../anilist/anilist.dart';
import '../anilist/recommender.dart';
import '../core/l10n.dart';
import '../core/motion.dart';
import '../core/services.dart';
import '../core/theme.dart';
import 'ink.dart';
import 'manga_page.dart';
import 'reco_book.dart';
import 'reco_symbols.dart';
import 'widgets.dart';

/// Recommendations (day mode): the nº 1 pick painted in with its main character,
/// an omikuji box for a new draw, and every category as a book on a shelf.
class RecoPage extends StatefulWidget {
  const RecoPage({super.key});

  @override
  State<RecoPage> createState() => _RecoPageState();
}

class _RecoPageState extends State<RecoPage> {
  Timer? _tick;
  int _drawNo = 0;

  @override
  void initState() {
    super.initState();
    Services.i.reco.onVisit();
    _tick = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _draw() {
    setState(() => _drawNo++);
    Services.i.reco.draw();
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
          final hero = reco.rows.isEmpty || reco.rows.first.items.isEmpty ? null : reco.rows.first.items.first;
          return ListView(padding: EdgeInsets.only(bottom: wide ? 30 : 120), children: [
            _Hero(hero: hero, wide: wide, pad: pad, drawNo: _drawNo, onDraw: _draw, status: _status(context, reco), loading: reco.loading),
            Padding(padding: EdgeInsets.symmetric(horizontal: pad), child: const SizedBox(height: 18, child: BrushShape(Brush.divider))),
            Padding(
              padding: EdgeInsets.fromLTRB(pad, 16, pad, 0),
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(
                  child: Wrap(crossAxisAlignment: WrapCrossAlignment.end, spacing: 14, children: [
                    Text(context.isEn ? 'Your shelves' : 'Tes rayons', style: Txt.h2(context).copyWith(fontSize: 28)),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        context.isEn ? 'Tap a book to open it · scroll the shelf' : 'Touche un livre pour l’ouvrir · fais défiler l’étagère',
                        style: Txt.caption(context).copyWith(fontSize: 13),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(width: 16),
                _ReloadButton(busy: reco.loading, onTap: _draw),
              ]),
            ),
            if (reco.error != null && reco.rows.isEmpty)
              Padding(
                padding: const EdgeInsets.all(40),
                child: EmptyState(
                  icon: Icons.wifi_off_rounded,
                  title: context.t('reco.error'),
                  action: AppButton(label: context.t('detail.retry'), tone: ButtonTone.quiet, onTap: reco.draw),
                ),
              )
            else
              _Shelf(rows: reco.rows, pad: pad, loading: reco.loading && reco.rows.isEmpty, key: ValueKey(reco.drawnAt)),
          ]);
        }),
      ),
    );
  }

  String _status(BuildContext context, Recommender reco) {
    if (reco.loading) return context.t('reco.loading');
    if (!reco.isFresh) return context.t('reco.ready');
    final left = reco.remaining;
    return '${context.t('reco.next')} ${left.inMinutes > 0 ? '${left.inMinutes} min' : '${left.inSeconds} s'}';
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.hero, required this.wide, required this.pad, required this.drawNo, required this.onDraw, required this.status, required this.loading});
  final AniMedia? hero;
  final bool wide, loading;
  final double pad;
  final int drawNo;
  final VoidCallback onDraw;
  final String status;

  @override
  Widget build(BuildContext context) {
    final intro = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(context.t('reco.title'), style: Txt.display(context).copyWith(fontSize: 54)),
      const SizedBox(height: 10),
      Text(context.t('reco.subtitle'), style: Txt.body(context)),
      const SizedBox(height: 26),
      _Omikuji(onDraw: onDraw, status: status, drawNo: drawNo, busy: loading),
    ]);

    final pick = hero == null
        ? const SizedBox.shrink()
        : Pressable(
            key: ValueKey(hero!.id),
            onTap: () => Navigator.of(context).push(SoftRoute(MangaPage.anilist(hero!))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              BrushCover(cover: hero!.cover, title: hero!.title, width: wide ? 206 : 150),
              SizedBox(width: wide ? 30 : 22),
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 260),
                  child: OneShot(
                    delay: const Duration(milliseconds: 450),
                    duration: const Duration(milliseconds: 400),
                    builder: (context, t, child) => Opacity(
                      opacity: t,
                      child: Transform.translate(offset: Offset(0, (1 - const Cubic(0.2, 0.8, 0.2, 1).transform(t)) * 18), child: child),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      InkTag(context.isEn ? 'MADE FOR YOU · Nº 1' : 'TAILLÉS POUR TOI · Nº 1'),
                      const SizedBox(height: 10),
                      Text(hero!.title, maxLines: 3, overflow: TextOverflow.ellipsis, style: Txt.display(context).copyWith(fontSize: wide ? 46 : 34, height: 0.98)),
                      const SizedBox(height: 8),
                      Text(
                        [if (hero!.meanScore != null) '★ ${(hero!.meanScore! / 10).toStringAsFixed(1).replaceAll('.', ',')}', ...hero!.genres.take(2)].join(' · '),
                        style: Txt.body(context).copyWith(fontSize: 15),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.only(bottom: 4),
                        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: inkRed, width: 3))),
                        child: Text(context.isEn ? 'See the page →' : 'Voir la fiche →', style: Txt.label(context).copyWith(fontSize: 15)),
                      ),
                    ]),
                  ),
                ),
              ),
            ]),
          );

    if (!wide) {
      return Padding(
        padding: EdgeInsets.fromLTRB(pad, 30, pad, 22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [intro, const SizedBox(height: 30), pick]),
      );
    }
    return SizedBox(
      height: 372,
      child: Stack(children: [
        if (hero != null) Positioned(right: 0, top: 0, width: 430, height: 372, child: InkPortrait(key: ValueKey(hero!.id), mediaId: hero!.id)),
        Padding(
          padding: EdgeInsets.fromLTRB(pad, 30, pad, 30),
          child: Row(children: [
            SizedBox(width: 280, child: intro),
            const SizedBox(width: 34),
            Flexible(child: pick),
            const SizedBox(width: 400),
          ]),
        ),
      ]),
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
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: inkBlack,
          border: Border.all(color: inkBlack, width: 2),
          boxShadow: const [BoxShadow(color: inkRed, offset: Offset(4, 4))],
        ),
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

/// Omikuji box: shakes, a stick pops out, and a fortune slip unrolls with a red seal.
class _Omikuji extends StatefulWidget {
  const _Omikuji({required this.onDraw, required this.status, required this.drawNo, required this.busy});
  final VoidCallback onDraw;
  final String status;
  final int drawNo;
  final bool busy;

  @override
  State<_Omikuji> createState() => _OmikujiState();
}

class _OmikujiState extends State<_Omikuji> with SingleTickerProviderStateMixin {
  late final _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
  OverlayEntry? _slip;
  Timer? _slipTimer;

  static const _fortunes = [('Grande chance', 'Great luck'), ('Chance', 'Good luck'), ('Petite chance', 'Small luck'), ('Chance à venir', 'Luck to come')];

  @override
  void dispose() {
    _shake.dispose();
    _slipTimer?.cancel();
    _slip?.remove();
    super.dispose();
  }

  Future<void> _tap() async {
    if (widget.busy || _shake.isAnimating) return;
    widget.onDraw();
    if (!Motion.reduced(context)) await _shake.forward(from: 0);
    if (!mounted) return;
    _showSlip();
  }

  void _showSlip() {
    _slip?.remove();
    _slipTimer?.cancel();
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final origin = box.localToGlobal(Offset.zero);
    final f = _fortunes[Random().nextInt(_fortunes.length)];
    final en = context.isEn;
    final n = widget.drawNo;
    _slip = OverlayEntry(
      builder: (_) => Positioned(
        left: origin.dx + 90,
        top: max(16, origin.dy - 230),
        child: IgnorePointer(child: _Slip(no: n, title: en ? f.$2 : f.$1, line: en ? 'New reads are waiting for you.' : 'De nouvelles lectures t’attendent.')),
      ),
    );
    Overlay.of(context).insert(_slip!);
    _slipTimer = Timer(const Duration(milliseconds: 2600), () {
      _slip?.remove();
      _slip = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: _tap,
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
        AnimatedBuilder(
          animation: _shake,
          builder: (context, _) {
            final t = _shake.value;
            // Shake: −14°, +12°, −10°, +8°, rest. The stick slides out during the last third.
            final angle = t == 0 ? 0.0 : sin(t * pi * 4) * (14 - 8 * t) * pi / 180 * (1 - t);
            final stick = t > 0.6 ? Curves.easeOutBack.transform((t - 0.6) / 0.4) : 0.0;
            return Transform.rotate(
              angle: angle,
              alignment: const Alignment(0, 0.8),
              child: SizedBox(width: 70, height: 112, child: CustomPaint(painter: _BoxPainter(stick))),
            );
          },
        ),
        const SizedBox(width: 18),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(context.t('reco.refresh'), style: Txt.h2(context).copyWith(fontSize: 24, height: 1)),
            const SizedBox(height: 4),
            Text(widget.status, style: Txt.label(context).copyWith(fontSize: 13, color: inkRed)),
          ]),
        ),
      ]),
    );
  }
}

class _BoxPainter extends CustomPainter {
  _BoxPainter(this.stick);
  final double stick;

  @override
  void paint(Canvas canvas, Size s) {
    final k = s.width / 76;
    canvas.scale(k, s.height / 120);
    // Stick (rises out of the box when drawn).
    canvas.save();
    canvas.translate(0, -26 * stick);
    canvas.drawRect(const Rect.fromLTWH(35, 4, 6, 34), Paint()..color = const Color(0xFFC9B88F));
    canvas.drawRect(const Rect.fromLTWH(35, 4, 6, 7), Paint()..color = inkRed);
    canvas.restore();
    final body = Path()
      ..moveTo(10, 26)
      ..lineTo(38, 16)
      ..lineTo(66, 26)
      ..lineTo(66, 112)
      ..lineTo(38, 118)
      ..lineTo(10, 112)
      ..close();
    canvas.drawPath(body, Paint()..color = inkRed);
    canvas.drawPath(body, Paint()
      ..color = inkBlack
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);
    canvas.drawLine(const Offset(38, 16), const Offset(38, 118), Paint()
      ..color = const Color(0xFF7E0C12)
      ..strokeWidth = 2);
    canvas.drawRect(const Rect.fromLTWH(18, 54, 40, 26), Paint()..color = inkPaper);
    canvas.drawRect(const Rect.fromLTWH(18, 54, 40, 26), Paint()
      ..color = inkBlack
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(_BoxPainter old) => old.stick != stick;
}

/// The fortune slip: unrolls downward, then the red seal lands.
class _Slip extends StatelessWidget {
  const _Slip({required this.no, required this.title, required this.line});
  final int no;
  final String title, line;

  @override
  Widget build(BuildContext context) {
    final paper = Container(
      width: 156,
      height: 320,
      padding: const EdgeInsets.fromLTRB(14, 22, 14, 20),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF8F1),
        border: Border.all(color: inkRed, width: 3),
        boxShadow: const [BoxShadow(color: inkBlack, spreadRadius: 5), BoxShadow(color: Color(0xFFFBF8F1), spreadRadius: 3)],
      ),
      child: Column(children: [
        Text('${context.isEn ? 'DRAW' : 'TIRAGE'} Nº $no', style: Txt.tag(context).copyWith(fontSize: 11, color: inkRed)),
        const SizedBox(height: 14),
        Text(title, textAlign: TextAlign.center, style: Txt.display(context).copyWith(fontSize: 32, height: 1)),
        const SizedBox(height: 14),
        Container(width: 40, height: 2, color: inkBlack),
        const SizedBox(height: 14),
        Text(line, textAlign: TextAlign.center, style: Txt.label(context).copyWith(fontSize: 13, height: 1.4)),
        const Spacer(),
        HankoStamp(text: '吉', size: 50, delay: const Duration(milliseconds: 650)),
      ]),
    );
    return OneShot(
      duration: const Duration(milliseconds: 700),
      builder: (context, t, child) {
        // Pops up small, then unrolls from the top.
        final pop = Curves.easeOutBack.transform((t / 0.35).clamp(0.0, 1.0));
        final unroll = const Cubic(0.6, 0, 0.2, 1).transform(((t - 0.35) / 0.65).clamp(0.0, 1.0));
        return Transform.translate(
          offset: Offset(0, 40 * (1 - pop)),
          child: Transform.scale(
            scale: 0.6 + 0.4 * pop,
            child: ClipRect(child: Align(alignment: Alignment.topCenter, heightFactor: max(0.04, unroll), child: child)),
          ),
        );
      },
      child: paper,
    );
  }
}

/// Category books on a scrolling shelf. Opening one bursts ink into the manga spread.
/// The books are drawn (no pictures) and all kept alive, so scrolling never rebuilds
/// them: they drop in once per draw and then stay put.
class _Shelf extends StatelessWidget {
  const _Shelf({super.key, required this.rows, required this.pad, required this.loading});
  final List<RecoRow> rows;
  final double pad;
  final bool loading;

  /// (book, ink, spine) as on the board: the first book red, then paper and ink alternately.
  static (Color, Color, Color) look(int i) => i == 0
      ? (inkRed, inkPaper, inkBlack)
      : i.isOdd
          ? (const Color(0xFFFBF8F1), inkBlack, inkBlack)
          : (inkBlack, inkPaper, inkRed);

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(
        height: 248,
        child: loading
            ? Center(child: Text(context.t('reco.loading'), style: Txt.caption(context)))
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.fromLTRB(pad, 14, pad, 22),
                child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  for (var i = 0; i < rows.length; i++) ...[
                    if (i > 0) const SizedBox(width: 22),
                    OneShot(
                      delay: Duration(milliseconds: 400 + 60 * min(i, 10)),
                      builder: (context, t, child) => Opacity(
                        opacity: t,
                        child: Transform.translate(offset: Offset(0, (1 - const Cubic(0.2, 1.2, 0.4, 1).transform(t)) * -30), child: child),
                      ),
                      child: RepaintBoundary(child: _Book(row: rows[i], look: look(i))),
                    ),
                  ],
                ]),
              ),
      ),
      Container(height: 6, margin: EdgeInsets.fromLTRB(pad, 0, pad, 0), color: inkBlack),
    ]);
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

class _Book extends StatefulWidget {
  const _Book({required this.row, required this.look});
  final RecoRow row;
  final (Color, Color, Color) look;

  @override
  State<_Book> createState() => _BookState();
}

class _BookState extends State<_Book> {
  bool _hover = false;

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
        onTap: () => Navigator.of(context).push(InkBurstRoute(RecoBookPage(rowKey: row.key))),
        child: AnimatedContainer(
          duration: Motion.fast,
          curve: const Cubic(0.2, 0.8, 0.2, 1),
          transform: Matrix4.translationValues(0, _hover ? -8 : 0, 0)..rotateZ(_hover ? -1.5 * pi / 180 : 0),
          width: 148,
          height: 212,
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: inkBlack, width: 2),
            boxShadow: const [BoxShadow(color: inkBlack, offset: Offset(6, 6))],
          ),
          child: Stack(children: [
            Positioned(left: 0, top: 0, bottom: 0, width: 12, child: ColoredBox(color: spine)),
            Positioned(
              left: 22,
              right: 10,
              top: 12,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(context.isEn ? row.labelEn : row.labelFr, softWrap: false, style: GoogleFonts.notoSerifJp(fontSize: 21, fontWeight: FontWeight.w800, color: fg, height: 1.05)),
                ),
                const SizedBox(height: 3),
                Text('${row.items.length} ${context.isEn ? 'titles' : 'titres'}', style: Txt.caption(context).copyWith(fontSize: 11, fontWeight: FontWeight.w700, color: fg.withValues(alpha: 0.75))),
              ]),
            ),
            // The category's figure, inked in the book's colours.
            Positioned(
              left: trio ? 10 : 30,
              bottom: trio ? -2 : 18,
              child: BookArt(category: row.key, ink: fg, paper: bg),
            ),
          ]),
        ),
      ),
    );
  }
}
