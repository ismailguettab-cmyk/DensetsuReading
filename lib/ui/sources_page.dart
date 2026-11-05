import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/l10n.dart';
import '../core/motion.dart';
import '../core/services.dart';
import '../core/theme.dart';
import '../sources/catalog.dart';
import '../sources/source.dart';
import 'ink.dart';
import 'shell.dart';
import 'widgets.dart';

/// Sources (day mode): language tabs underlined in red brush, installed sources on paper
/// with a red "INSTALLÉE" seal, available ones in dashed outline.
class SourcesPage extends StatefulWidget {
  const SourcesPage({super.key});

  @override
  State<SourcesPage> createState() => _SourcesPageState();
}

class _SourcesPageState extends State<SourcesPage> {
  String _lang = '';
  bool _byName = false;

  @override
  Widget build(BuildContext context) {
    final store = Services.i.sources;
    final pad = pagePadding(context);
    return Scaffold(
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final list = allSources.where((s) => _lang.isEmpty || s.lang == _lang).toList()
            ..sort((a, b) => _byName ? a.name.compareTo(b.name) : b.popularity.compareTo(a.popularity));
          final mine = list.where(store.isInstalled).toList();
          final available = list.where((s) => !store.isInstalled(s)).toList();
          return ListView(padding: pad, children: [
            Text(context.t('sources.title'), style: Txt.display(context).copyWith(fontSize: 54)),
            const SizedBox(height: 8),
            Text(context.t('sources.subtitle'), style: Txt.body(context).copyWith(fontSize: 16)),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.only(bottom: 6),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: inkBlack, width: 2))),
              child: Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, runSpacing: 10, children: [
                Wrap(spacing: 22, children: [
                  for (final (k, label) in [('', context.t('sources.all')), ('fr', languageName('fr', context.isEn)), ('en', languageName('en', context.isEn)), ('ja', languageName('ja', context.isEn))])
                    _Tab(label: label, active: _lang == k, onTap: () => setState(() => _lang = k)),
                ]),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(context.isEn ? 'Sort by' : 'Trier par', style: Txt.body(context).copyWith(fontSize: 14, color: context.pal.text3)),
                  const SizedBox(width: 10),
                  _Square(label: context.t('sources.byPopularity'), active: !_byName, onTap: () => setState(() => _byName = false)),
                  _Square(label: context.t('sources.byName'), active: _byName, onTap: () => setState(() => _byName = true)),
                ]),
              ]),
            ),
            if (mine.isNotEmpty) ...[
              const SizedBox(height: 20),
              _Heading(context.t('sources.mine'), mine.length),
              const SizedBox(height: 12),
              _Grid(sources: mine, base: 0),
            ],
            if (available.isNotEmpty) ...[
              const SizedBox(height: 26),
              _Heading(context.t('sources.available'), available.length),
              const SizedBox(height: 12),
              _Grid(sources: available, base: 200),
            ],
          ]);
        },
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text, this.count);
  final String text;
  final int count;

  @override
  Widget build(BuildContext context) => Text.rich(TextSpan(children: [
        TextSpan(text: text, style: Txt.h2(context)),
        TextSpan(text: '  · $count', style: Txt.caption(context).copyWith(fontSize: 14)),
      ]));
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
            if (active) const Positioned(left: -4, right: -4, bottom: 4, child: InkUnderline()),
            Text(label, style: Txt.label(context).copyWith(fontSize: 16, fontWeight: active ? FontWeight.w900 : FontWeight.w500)),
          ]),
        ),
      );
}

class _Square extends StatelessWidget {
  const _Square({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Transform.translate(
        offset: const Offset(-2, 0),
        child: Pressable(
          onTap: onTap,
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: active ? inkBlack : Colors.transparent, border: Border.all(color: inkBlack, width: 2)),
            child: Text(label, style: Txt.label(context).copyWith(color: active ? inkPaper : inkBlack)),
          ),
        ),
      );
}

class _Grid extends StatelessWidget {
  const _Grid({required this.sources, required this.base});
  final List<MangaSource> sources;
  final int base;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final columns = box.maxWidth >= 700 ? 2 : 1;
      const gap = 24.0;
      final w = (box.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(spacing: gap, runSpacing: 12, children: [
        for (var i = 0; i < sources.length; i++)
          SizedBox(
            width: w,
            child: OneShot(
              key: ValueKey(sources[i].id),
              delay: Duration(milliseconds: base + 40 * min(i, 14)),
              builder: (context, t, child) => Opacity(
                opacity: t,
                child: Transform.translate(offset: Offset(0, 12 * (1 - const Cubic(0.2, 0.8, 0.2, 1).transform(t))), child: child),
              ),
              child: SourceTile(source: sources[i], angle: ((i * 37) % 40 - 20) * pi / 180),
            ),
          ),
      ]);
    });
  }
}

/// One source row. Also used by the Search tab when nothing is installed yet.
class SourceTile extends StatelessWidget {
  const SourceTile({super.key, required this.source, this.angle = 0});

  final MangaSource source;
  final double angle;

  @override
  Widget build(BuildContext context) {
    final store = Services.i.sources;
    final installed = store.isInstalled(source);
    final pop = (source.popularity / 20).ceil().clamp(1, 5);
    final row = Row(children: [
      SizedBox(
        width: 48,
        height: 44,
        child: Stack(alignment: Alignment.center, children: [
          Transform.rotate(
            angle: angle,
            child: installed ? const InkBlot(width: 48, height: 44) : const CustomPaint(size: Size(48, 44), painter: _BlotOutline()),
          ),
          Text(
            InitialsBlot.initials(source.name),
            style: GoogleFonts.notoSerifJp(fontSize: 15, fontWeight: FontWeight.w800, color: installed ? inkPaper : inkBlack),
          ),
        ]),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(source.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Txt.title(context).copyWith(fontSize: 16)),
          const SizedBox(height: 3),
          Row(children: [
            Text(languageName(source.lang, context.isEn), style: Txt.caption(context)),
            const SizedBox(width: 10),
            for (var k = 1; k <= 5; k++)
              Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.only(right: 3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: k <= pop ? inkBlack : Colors.transparent,
                  border: Border.all(color: inkBlack, width: 1.5),
                ),
              ),
          ]),
        ]),
      ),
      const SizedBox(width: 10),
      AnimatedSwitcher(
        duration: Motion.fast,
        child: installed
            ? Pressable(
                key: const ValueKey('remove'),
                onTap: () => store.remove(source),
                child: Tooltip(
                  message: context.t('sources.remove'),
                  child: OneShot(
                    duration: const Duration(milliseconds: 300),
                    builder: (context, t, child) {
                      final s = t < 0.6 ? 2 - 1.08 * (t / 0.6) : 0.92 + 0.08 * ((t - 0.6) / 0.4);
                      return Opacity(opacity: (t / 0.4).clamp(0.0, 1.0), child: Transform.rotate(angle: -6 * pi / 180, child: Transform.scale(scale: s, child: child)));
                    },
                    child: Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(border: Border.all(color: inkRed, width: 2)),
                      child: Text(context.isEn ? 'INSTALLED' : 'INSTALLÉE', style: Txt.tag(context).copyWith(color: inkRed, letterSpacing: 1)),
                    ),
                  ),
                ),
              )
            : Pressable(
                key: const ValueKey('install'),
                onTap: () => store.install(source),
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  alignment: Alignment.center,
                  color: inkBlack,
                  child: Text(context.t('sources.install'), style: Txt.label(context).copyWith(color: inkPaper)),
                ),
              ),
      ),
    ]);
    return Container(
      constraints: const BoxConstraints(minHeight: 68),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: installed ? BoxDecoration(color: const Color(0xFFFBF8F1), border: Border.all(color: inkBlack, width: 2)) : null,
      foregroundDecoration: installed ? null : const _DashedBorder(),
      child: row,
    );
  }
}

class _BlotOutline extends CustomPainter {
  const _BlotOutline();

  @override
  void paint(Canvas canvas, Size size) {
    final path = scaledPath('M10 14C18 3 44 1 55 9c9 7 8 26-1 35-10 10-33 13-44 4C1 41 3 23 10 14z', const Size(64, 58), size);
    canvas.drawPath(path, Paint()
      ..color = inkBlack
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5);
  }

  @override
  bool shouldRepaint(_BlotOutline old) => false;
}

/// 2 px dashed ink border (available sources).
class _DashedBorder extends Decoration {
  const _DashedBorder();

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) => _DashedPainter();
}

class _DashedPainter extends BoxPainter {
  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration config) {
    final r = (offset & config.size!).deflate(1);
    final paint = Paint()
      ..color = inkBlack
      ..strokeWidth = 2;
    void dash(Offset a, Offset b) {
      final len = (b - a).distance, dir = (b - a) / len;
      for (var d = 0.0; d < len; d += 9) {
        canvas.drawLine(a + dir * d, a + dir * min(d + 5, len), paint);
      }
    }

    dash(r.topLeft, r.topRight);
    dash(r.topRight, r.bottomRight);
    dash(r.bottomRight, r.bottomLeft);
    dash(r.bottomLeft, r.topLeft);
  }
}

/// Square ink chip used by the search filters.
class FilterChipButton extends StatelessWidget {
  const FilterChipButton({super.key, required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        scale: 0.95,
        child: AnimatedContainer(
          duration: Motion.fast,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          decoration: BoxDecoration(color: selected ? inkBlack : Colors.transparent, border: Border.all(color: inkBlack, width: 2)),
          child: Text(label, style: Txt.label(context).copyWith(fontSize: 13, color: selected ? inkPaper : inkBlack)),
        ),
      );
}
