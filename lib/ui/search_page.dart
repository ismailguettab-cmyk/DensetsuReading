import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/l10n.dart';
import '../core/motion.dart';
import '../core/services.dart';
import '../core/theme.dart';
import '../sources/catalog.dart';
import '../sources/mangadex.dart';
import '../sources/source.dart';
import 'ink.dart';
import 'manga_page.dart';
import 'shell.dart';
import 'sources_page.dart';
import 'widgets.dart';

/// Browse one source directly (from the Sources tab). Step 1: pick a source. Step 2: search inside it.
/// The source cards open like book covers each time the tab is shown.
class SourceBrowserPage extends StatefulWidget {
  const SourceBrowserPage({super.key});

  @override
  State<SourceBrowserPage> createState() => _SourceBrowserPageState();
}

class _SourceBrowserPageState extends State<SourceBrowserPage> {
  ValueListenable<int>? _tab;
  int _replay = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tab = ShellScope.of(context).current;
    if (tab == _tab) return;
    _tab?.removeListener(_onTab);
    _tab = tab..addListener(_onTab);
  }

  void _onTab() {
    if (_tab?.value == 3 && mounted) setState(() => _replay++);
  }

  @override
  void dispose() {
    _tab?.removeListener(_onTab);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = Services.i.sources;
    final pad = pagePadding(context);
    return Scaffold(
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final installed = store.installed;
          if (installed.isEmpty) {
            final suggested = [...allSources]..sort((a, b) => b.popularity.compareTo(a.popularity));
            return ListView(padding: pad, children: [
              Text(context.t('search.title'), style: Txt.display(context)),
              const SizedBox(height: 40),
              EmptyState(icon: Icons.extension_rounded, title: context.t('search.none'), text: context.t('search.noneText')),
              const SizedBox(height: 36),
              _SourceGrid(sources: suggested, install: true),
            ]);
          }
          return _PageTurn(
            key: ValueKey(_replay),
            child: ListView(padding: pad, children: [
              if (Navigator.of(context).canPop()) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconCircle(icon: Icons.arrow_back_rounded, onTap: () => Navigator.of(context).maybePop(), tooltip: context.t('common.back')),
                ),
                const SizedBox(height: 18),
              ],
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Stack(clipBehavior: Clip.none, children: [
                      const Positioned(left: -6, right: -10, bottom: -6, child: SizedBox(height: 22, child: _TitleUnderline())),
                      Text(context.t('search.title'), style: Txt.display(context).copyWith(fontSize: 54)),
                    ]),
                    const SizedBox(height: 10),
                    Text(context.t('search.pick'), style: Txt.body(context).copyWith(fontSize: 16)),
                  ]),
                ),
                Text(
                  '${installed.length} ${context.isEn ? 'sources installed' : 'sources installées'}',
                  style: Txt.label(context).copyWith(fontSize: 13, color: context.pal.text3),
                ),
              ]),
              const SizedBox(height: 26),
              _SourceGrid(sources: installed, replay: _replay),
            ]),
          );
        },
      ),
    );
  }
}

class _TitleUnderline extends StatelessWidget {
  const _TitleUnderline();

  @override
  Widget build(BuildContext context) => const PaintReveal(
        delay: Duration(milliseconds: 150),
        duration: Duration(milliseconds: 400),
        curve: Cubic(0.8, 0, 0.2, 1),
        child: BrushShape(Brush.underline, color: inkRed),
      );
}

/// Arriving on the tab: the previous page turns away on its left edge, its shadow fading.
class _PageTurn extends StatelessWidget {
  const _PageTurn({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) return child;
    return Stack(children: [
      child,
      IgnorePointer(
        child: OneShot(
          delay: const Duration(milliseconds: 50),
          duration: const Duration(milliseconds: 750),
          builder: (context, t, _) {
            if (t >= 1) return const SizedBox.shrink();
            final e = const Cubic(0.55, 0, 0.25, 1).transform(t);
            return Stack(children: [
              Positioned.fill(child: ColoredBox(color: inkBlack.withValues(alpha: 0.35 * (1 - t)))),
              Positioned.fill(
                child: Transform(
                  alignment: Alignment.centerLeft,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 1 / 2200)
                    ..rotateY(-e * 100 * pi / 180),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFFFBF8F1),
                      border: Border(right: BorderSide(color: inkBlack, width: 2)),
                      gradient: LinearGradient(colors: [Color(0xFFFBF8F1), Color(0xFFFBF8F1), Color(0x2E121010)], stops: [0, 0.96, 1]),
                    ),
                    child: const Align(alignment: Alignment(0.5, -0.1), child: InkBlot(width: 380, height: 380)),
                  ),
                ),
              ),
            ]);
          },
        ),
      ),
    ]);
  }
}

class _SourceGrid extends StatelessWidget {
  const _SourceGrid({required this.sources, this.install = false, this.replay = 0});
  final List<MangaSource> sources;
  final bool install;
  final int replay;

  @override
  Widget build(BuildContext context) {
    const rots = [-8.0, 12.0, -3.0, 20.0, -14.0, 6.0, -20.0, 9.0, -6.0];
    return LayoutBuilder(builder: (context, box) {
      final columns = (box.maxWidth / 200).floor().clamp(2, 5);
      const gap = 24.0;
      final w = (box.maxWidth - gap * (columns - 1)) / columns;
      Widget cardIn(int i, Widget child) => OneShot(
            key: ValueKey('$replay-$i'),
            delay: Duration(milliseconds: 300 + 50 * min(i, 12)),
            duration: const Duration(milliseconds: 400),
            builder: (context, t, c) {
              final e = const Cubic(0.2, 0.8, 0.2, 1).transform(t);
              return Opacity(
                opacity: t,
                child: Transform.translate(offset: Offset(0, 24 * (1 - e)), child: Transform.rotate(angle: -3 * pi / 180 * (1 - e), child: c)),
              );
            },
            child: child,
          );
      return Wrap(spacing: gap, runSpacing: gap, children: [
        for (var i = 0; i < sources.length; i++)
          SizedBox(
            width: install ? (box.maxWidth >= 700 ? (box.maxWidth - 16) / 2 : box.maxWidth) : w,
            child: install
                ? Reveal(index: i, child: SourceTile(source: sources[i]))
                : cardIn(
                    i,
                    _SourceCard(
                      source: sources[i],
                      angle: rots[i % rots.length] * pi / 180,
                      onTap: () => Navigator.of(context).push(SoftRoute(SourceSearchPage(source: sources[i]))),
                    ),
                  ),
          ),
        if (!install)
          SizedBox(
            width: w,
            child: cardIn(
              sources.length,
              Pressable(
                onTap: () => ShellScope.of(context).select(3),
                child: Container(
                  height: 252,
                  decoration: BoxDecoration(border: Border.all(color: inkBlack, width: 2)),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(color: inkRed, shape: BoxShape.circle),
                      child: const Icon(Icons.add_rounded, color: inkPaper, size: 28),
                    ),
                    const SizedBox(height: 12),
                    Text(context.isEn ? 'Add a source' : 'Ajouter une source', style: Txt.h2(context).copyWith(fontSize: 18)),
                    const SizedBox(height: 2),
                    Text(context.isEn ? 'in the Sources tab' : 'dans l’onglet Sources', style: Txt.caption(context)),
                  ]),
                ),
              ),
            ),
          ),
      ]);
    });
  }
}

/// Paper card: the source's initials in an ink blot, its language on a tilted red tag.
/// Lifts and deepens its ink shadow under the pointer.
class _SourceCard extends StatefulWidget {
  const _SourceCard({required this.source, required this.onTap, this.angle = 0});
  final MangaSource source;
  final VoidCallback onTap;
  final double angle;

  @override
  State<_SourceCard> createState() => _SourceCardState();
}

class _SourceCardState extends State<_SourceCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.source;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Pressable(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: Motion.fast,
          curve: const Cubic(0.2, 0.8, 0.2, 1),
          height: 252,
          transform: Matrix4.translationValues(0, _hover ? -6 : 0, 0)..rotateZ(_hover ? -1 * pi / 180 : 0),
          decoration: BoxDecoration(
            color: const Color(0xFFFBF8F1),
            border: Border.all(color: inkBlack, width: 2),
            boxShadow: [BoxShadow(color: inkBlack, offset: _hover ? const Offset(9, 9) : const Offset(5, 5))],
          ),
          child: Stack(children: [
            Align(alignment: const Alignment(0, -0.62), child: InitialsBlot(name: s.name, angle: widget.angle)),
            Positioned(
              right: 12,
              top: 12,
              child: Transform.rotate(
                angle: -8 * pi / 180,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(border: Border.all(color: inkRed, width: 2)),
                  child: Text(s.lang.toUpperCase(), style: Txt.tag(context).copyWith(color: inkRed, letterSpacing: 1)),
                ),
              ),
            ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 22,
              child: Column(children: [
                Text(s.name, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: Txt.h2(context).copyWith(fontSize: 20, height: 1.1)),
                const SizedBox(height: 4),
                Text(languageName(s.lang, context.isEn), style: Txt.caption(context)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Search bar, filters and results for one source.
class SourceSearchPage extends StatefulWidget {
  const SourceSearchPage({super.key, required this.source});
  final MangaSource source;

  @override
  State<SourceSearchPage> createState() => _SourceSearchPageState();
}

class _SourceSearchPageState extends State<SourceSearchPage> {
  final _query = TextEditingController();
  final _scroll = ScrollController();
  final FilterValues _filters = {};
  final List<SourceManga> _items = [];
  Timer? _debounce;
  int _page = 1;
  bool _hasNext = true;
  bool _loading = false;
  Object? _error;
  int _generation = 0;

  MangaSource get source => widget.source;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 600) _load();
    });
    if (source is MangaDex) MangaDex.loadTags().then((_) => mounted ? setState(() {}) : null).catchError((_) {});
    _reset();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    _query.dispose();
    super.dispose();
  }

  void _reset() {
    _generation++;
    setState(() {
      _items.clear();
      _page = 1;
      _hasNext = true;
      _error = null;
      _loading = false;
    });
    _load();
  }

  Future<void> _load() async {
    if (_loading || !_hasNext) return;
    final generation = _generation;
    setState(() => _loading = true);
    try {
      final q = _query.text.trim();
      final result = q.isEmpty && _filters.isEmpty ? await source.popular(_page) : await source.search(q, _page, _filters);
      if (generation != _generation || !mounted) return;
      setState(() {
        final seen = _items.map((m) => m.url).toSet();
        _items.addAll(result.items.where((m) => seen.add(m.url)));
        _hasNext = result.hasNext && result.items.isNotEmpty;
        _page++;
      });
    } catch (e) {
      if (generation == _generation && mounted) setState(() => _error = e);
    } finally {
      if (generation == _generation && mounted) setState(() => _loading = false);
    }
  }

  void _onQuery(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      if (value.trim().isNotEmpty) Services.i.activity.logSearch(value);
      _reset();
    });
  }

  int get _activeFilters => _filters.values.where((v) => v is String ? v.isNotEmpty : (v as Set).isNotEmpty).length;

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<FilterValues>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterSheet(source: source, initial: _filters),
    );
    if (result == null) return;
    setState(() {
      _filters
        ..clear()
        ..addAll(result);
    });
    _reset();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final pad = pagePadding(context);
    final q = _query.text.trim();
    return Scaffold(
      body: CustomScrollView(controller: _scroll, slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(pad.left, pad.top, pad.right, 0),
          sliver: SliverToBoxAdapter(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                IconCircle(icon: Icons.arrow_back_rounded, onTap: () => Navigator.of(context).pop(), tooltip: context.t('search.change')),
                const SizedBox(width: 16),
                InitialsBlot(name: source.name, size: 58),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(source.name, style: Txt.h1(context)),
                    Text(languageName(source.lang, context.isEn), style: Txt.caption(context)),
                  ]),
                ),
              ]),
              const SizedBox(height: 26),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _query,
                    onChanged: _onQuery,
                    onSubmitted: (v) {
                      _debounce?.cancel();
                      Services.i.activity.logSearch(v);
                      _reset();
                    },
                    textInputAction: TextInputAction.search,
                    style: Txt.label(context).copyWith(fontSize: 15, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      hintText: context.t('search.hint'),
                      hintStyle: Txt.label(context).copyWith(fontSize: 15, color: p.text3, fontWeight: FontWeight.w500),
                      prefixIcon: Icon(Icons.search_rounded, color: p.text3),
                      suffixIcon: q.isEmpty
                          ? null
                          : IconButton(
                              icon: Icon(Icons.close_rounded, color: p.text3, size: 20),
                              onPressed: () {
                                _query.clear();
                                _reset();
                              },
                            ),
                      filled: true,
                      fillColor: p.surface,
                      contentPadding: const EdgeInsets.symmetric(vertical: 17),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: p.accent, width: 1.4)),
                    ),
                  ),
                ),
                if (source.filters.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  Pressable(
                    onTap: _openFilters,
                    child: AnimatedContainer(
                      duration: Motion.fast,
                      height: 54,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      decoration: BoxDecoration(
                        color: _activeFilters > 0 ? p.accent : p.surface,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(children: [
                        Icon(Icons.tune_rounded, size: 19, color: _activeFilters > 0 ? p.bg : p.text),
                        const SizedBox(width: 8),
                        Text(
                          _activeFilters > 0 ? '${context.t('search.filters')} · $_activeFilters' : context.t('search.filters'),
                          style: Txt.label(context).copyWith(color: _activeFilters > 0 ? p.bg : p.text),
                        ),
                      ]),
                    ),
                  ),
                ],
              ]),
              if (q.isNotEmpty && _activeFilters > 0 && !source.filtersWithQuery) ...[
                const SizedBox(height: 10),
                Text(context.t('search.unsupported'), style: Txt.caption(context)),
              ],
              const SizedBox(height: 28),
              Text(q.isEmpty && _activeFilters == 0 ? '${context.t('search.popular')} ${source.name}' : context.t('search.results'), style: Txt.h2(context)),
              const SizedBox(height: 18),
            ]),
          ),
        ),
        if (_items.isEmpty && _loading)
          SliverFillRemaining(hasScrollBody: false, child: _InkingSheet(sourceName: source.name))
        else if (_items.isEmpty && !_loading)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _error != null
                ? EmptyState(
                    icon: Icons.wifi_off_rounded,
                    title: context.t('detail.error'),
                    action: AppButton(label: context.t('detail.retry'), tone: ButtonTone.quiet, onTap: _reset),
                  )
                : EmptyState(icon: Icons.search_off_rounded, title: context.t('search.empty')),
          )
        else
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: pad.left),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 168,
                mainAxisSpacing: 26,
                crossAxisSpacing: 18,
                childAspectRatio: 0.52,
              ),
              itemCount: _items.length,
              itemBuilder: (context, i) {
                final m = _items[i];
                final tag = 'src-${m.sourceId}-${m.url}';
                return _BlotReveal(
                  delay: Duration(milliseconds: 150 + (i % 24) ~/ 6 * 250 + (i * 53) % 250),
                  red: i % 5 == 2,
                  child: MangaCard(
                    width: double.infinity,
                    title: m.title,
                    cover: m.cover,
                    headers: source.imageHeaders,
                    heroTag: tag,
                    onTap: () => Navigator.of(context).push(SoftRoute(MangaPage.source(m, heroTag: tag))),
                  ),
                );
              },
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(top: 20, bottom: pad.bottom),
            child: _loading && _items.isNotEmpty ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: inkBlack)) : null,
          ),
        ),
      ]),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.source, required this.initial});
  final MangaSource source;
  final FilterValues initial;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late final FilterValues _values = {
    for (final e in widget.initial.entries) e.key: e.value is Set<String> ? {...(e.value as Set<String>)} : e.value,
  };

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final size = MediaQuery.sizeOf(context);
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 760, maxHeight: size.height * 0.86),
        child: Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(28)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 10),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(2))),
            Flexible(
              child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(26, 18, 26, 10), children: [
                Text(context.t('search.filters'), style: Txt.h1(context)),
                for (final f in widget.source.filters) ...[
                  const SizedBox(height: 24),
                  Text(f.label(context.isEn), style: Txt.label(context).copyWith(color: p.text2)),
                  const SizedBox(height: 12),
                  if (f.options.isEmpty)
                    const SizedBox(height: 32, child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
                  else
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final o in f.options)
                        FilterChipButton(
                          label: o.label(context.isEn),
                          selected: f.kind == FilterKind.single
                              ? (_values[f.key] as String? ?? f.options.first.value) == o.value
                              : (_values[f.key] as Set<String>? ?? const {}).contains(o.value),
                          onTap: () => setState(() {
                            if (f.kind == FilterKind.single) {
                              if (o.value.isEmpty || o.value == f.options.first.value && f.key != 'sort') {
                                _values.remove(f.key);
                              } else {
                                _values[f.key] = o.value;
                              }
                            } else {
                              final set = (_values[f.key] as Set<String>?) ?? <String>{};
                              set.contains(o.value) ? set.remove(o.value) : set.add(o.value);
                              if (set.isEmpty) {
                                _values.remove(f.key);
                              } else {
                                _values[f.key] = set;
                              }
                            }
                          }),
                        ),
                    ]),
                ],
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(26, 8, 26, 22),
              child: Row(children: [
                AppButton(label: context.t('search.reset'), tone: ButtonTone.quiet, onTap: () => setState(_values.clear)),
                const Spacer(),
                AppButton(label: context.t('search.apply'), tone: ButtonTone.accent, onTap: () => Navigator.pop(context, _values)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// While the first page loads: a sheet sways and gets inked stroke by stroke, then flooded.
class _InkingSheet extends StatefulWidget {
  const _InkingSheet({required this.sourceName});
  final String sourceName;

  @override
  State<_InkingSheet> createState() => _InkingSheetState();
}

class _InkingSheetState extends State<_InkingSheet> with SingleTickerProviderStateMixin {
  late final _sway = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..repeat();

  static const _strokes = [
    (-20.0, 30.0, 300.0, 70.0, -8.0, 0, false, false),
    (-10.0, 110.0, 290.0, 80.0, 6.0, 160, true, false),
    (-30.0, 190.0, 320.0, 70.0, -4.0, 320, false, false),
    (10.0, 150.0, 220.0, 40.0, -14.0, 460, true, true),
    (-20.0, 250.0, 300.0, 90.0, 9.0, 580, true, false),
    (0.0, 70.0, 280.0, 60.0, 32.0, 720, false, false),
    (-20.0, 170.0, 300.0, 60.0, -28.0, 860, false, false),
    (-10.0, 0.0, 280.0, 70.0, 3.0, 1000, true, false),
    (-10.0, 284.0, 290.0, 70.0, -3.0, 1140, false, false),
  ];

  @override
  void dispose() {
    _sway.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = Motion.reduced(context);
    final sheet = Container(
      width: 260,
      height: 340,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: const Color(0xFFFBF8F1),
        border: Border.all(color: inkBlack, width: 2),
        boxShadow: const [BoxShadow(color: Color(0x40121010), offset: Offset(8, 8))],
      ),
      child: Stack(clipBehavior: Clip.hardEdge, children: [
        for (final (x, y, w, h, r, d, left, red) in _strokes)
          Positioned(
            left: x,
            top: y,
            width: w,
            height: h,
            child: Transform.rotate(
              angle: r * pi / 180,
              child: PaintReveal(
                delay: Duration(milliseconds: d),
                duration: const Duration(milliseconds: 170),
                fromRight: left,
                child: BrushShape(left ? Brush.sweepLeft : Brush.sweepRight, color: red ? inkRed : inkBlack),
              ),
            ),
          ),
        const Positioned.fill(
          child: InkDots(
            delay: Duration(milliseconds: 240),
            dots: [(0.15, 0.18, 22, false), (0.77, 0.41, 18, false), (0.31, 0.74, 26, false), (0.75, 0.88, 14, true), (0.54, 0.12, 16, false)],
          ),
        ),
        const Positioned.fill(
          child: PaintReveal(delay: Duration(milliseconds: 1400), duration: Duration(milliseconds: 350), curve: Cubic(0.8, 0, 0.2, 1), child: ColoredBox(color: inkBlack)),
        ),
      ]),
    );
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      if (reduced)
        sheet
      else
        AnimatedBuilder(
          animation: _sway,
          builder: (context, child) => Transform.rotate(angle: sin(_sway.value * 2 * pi) * 1.5 * pi / 180, child: child),
          child: sheet,
        ),
      const SizedBox(height: 30),
      Text(context.isEn ? 'Inking the covers…' : 'On encre les jaquettes…', style: Txt.h2(context).copyWith(fontSize: 26)),
      const SizedBox(height: 4),
      Text('${context.t('search.popular')} ${widget.sourceName}', style: Txt.caption(context).copyWith(fontSize: 14)),
    ]);
  }
}

/// A drop of ink lands on the slot, spreads, then wipes away to reveal the cover in colour.
class _BlotReveal extends StatelessWidget {
  const _BlotReveal({required this.child, required this.delay, this.red = false});
  final Widget child;
  final Duration delay;
  final bool red;

  @override
  Widget build(BuildContext context) {
    return OneShot(
      delay: delay,
      duration: const Duration(milliseconds: 600),
      builder: (context, t, c) {
        final grow = const Cubic(0.6, 0, 0.3, 1).transform((t / 0.42).clamp(0.0, 1.0));
        final wipe = const Cubic(0.6, 0, 0.3, 1).transform(((t - 0.42) / 0.58).clamp(0.0, 1.0));
        final color = Curves.easeOut.transform(((t - 0.41) / 0.59).clamp(0.0, 1.0));
        return Stack(clipBehavior: Clip.none, children: [
          Opacity(opacity: t > 0.41 ? 1 : 0, child: Colorized(t: color, child: c!)),
          if (wipe < 1)
            Positioned.fill(
              child: IgnorePointer(
                child: ClipRect(
                  clipper: _WipeClip(wipe),
                  child: Align(
                    alignment: const Alignment(0, -0.35),
                    child: Transform.rotate(
                      angle: (1 - grow) * -30 * pi / 180,
                      child: Transform.scale(scale: 0.01 + 2.3 * grow, child: InkBlot(width: 64, height: 58, color: red ? inkRed : inkBlack)),
                    ),
                  ),
                ),
              ),
            ),
        ]);
      },
      child: child,
    );
  }
}

class _WipeClip extends CustomClipper<Rect> {
  _WipeClip(this.t);
  final double t;

  @override
  Rect getClip(Size s) => Rect.fromLTRB(s.width * t, -200, s.width + 200, s.height + 200);

  @override
  bool shouldReclip(_WipeClip old) => old.t != t;
}
