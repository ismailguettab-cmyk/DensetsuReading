import 'dart:async';

import 'package:flutter/material.dart';

import '../core/l10n.dart';
import '../core/motion.dart';
import '../core/services.dart';
import '../core/theme.dart';
import '../sources/catalog.dart';
import '../sources/mangadex.dart';
import '../sources/source.dart';
import 'manga_page.dart';
import 'shell.dart';
import 'sources_page.dart';
import 'widgets.dart';

/// Step 1: pick a source (or install one). Step 2: search inside it.
class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

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
          return ListView(padding: pad, children: [
            Text(context.t('search.title'), style: Txt.display(context)),
            const SizedBox(height: 8),
            Text(context.t('search.pick'), style: Txt.body(context)),
            const SizedBox(height: 28),
            _SourceGrid(sources: installed),
          ]);
        },
      ),
    );
  }
}

class _SourceGrid extends StatelessWidget {
  const _SourceGrid({required this.sources, this.install = false});
  final List<MangaSource> sources;
  final bool install;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final columns = (box.maxWidth / 220).floor().clamp(2, 6);
      const gap = 16.0;
      final w = (box.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(spacing: gap, runSpacing: gap, children: [
        for (var i = 0; i < sources.length; i++)
          SizedBox(
            width: install ? (box.maxWidth >= 700 ? (box.maxWidth - gap) / 2 : box.maxWidth) : w,
            child: Reveal(
              index: i,
              child: install
                  ? SourceTile(source: sources[i])
                  : _SourceCard(
                      source: sources[i],
                      onTap: () => Navigator.of(context).push(SoftRoute(SourceSearchPage(source: sources[i]))),
                    ),
            ),
          ),
      ]);
    });
  }
}

/// Big square card: logo, name, language.
class _SourceCard extends StatelessWidget {
  const _SourceCard({required this.source, required this.onTap});
  final MangaSource source;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Pressable(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 1.05,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: p.line)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SourceLogo(source, size: 58),
            const Spacer(),
            Text(source.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Txt.h2(context)),
            const SizedBox(height: 4),
            Text(languageName(source.lang, context.isEn), style: Txt.caption(context)),
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
                SourceLogo(source, size: 40),
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
        if (_items.isEmpty && !_loading)
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
                return Reveal(
                  index: i % 24,
                  step: 25,
                  offset: 8,
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
            child: _loading ? Center(child: CircularProgressIndicator(strokeWidth: 2, color: p.accent)) : null,
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
