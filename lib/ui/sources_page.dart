import 'package:flutter/material.dart';

import '../core/l10n.dart';
import '../core/motion.dart';
import '../core/services.dart';
import '../core/theme.dart';
import '../sources/catalog.dart';
import '../sources/source.dart';
import 'shell.dart';
import 'widgets.dart';

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
    final langs = {for (final s in allSources) s.lang}.toList()..sort((a, b) => a == 'fr' ? -1 : (b == 'fr' ? 1 : a.compareTo(b)));
    return Scaffold(
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final list = allSources.where((s) => _lang.isEmpty || s.lang == _lang).toList()
            ..sort((a, b) => _byName ? a.name.compareTo(b.name) : b.popularity.compareTo(a.popularity));
          final mine = list.where(store.isInstalled).toList();
          final available = list.where((s) => !store.isInstalled(s)).toList();
          return ListView(padding: pad, children: [
            Text(context.t('sources.title'), style: Txt.display(context)),
            const SizedBox(height: 8),
            Text(context.t('sources.subtitle'), style: Txt.body(context)),
            const SizedBox(height: 26),
            Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
              _Chip(label: context.t('sources.all'), selected: _lang.isEmpty, onTap: () => setState(() => _lang = '')),
              for (final l in langs)
                _Chip(label: languageName(l, context.isEn), selected: _lang == l, onTap: () => setState(() => _lang = l)),
              const SizedBox(width: 12),
              SizedBox(
                width: 240,
                child: Segmented<bool>(
                  value: _byName,
                  options: [(false, context.t('sources.byPopularity')), (true, context.t('sources.byName'))],
                  onChanged: (v) => setState(() => _byName = v),
                ),
              ),
            ]),
            if (mine.isNotEmpty) ...[
              const SizedBox(height: 34),
              SectionTitle(context.t('sources.mine')),
              _Grid(sources: mine),
            ],
            if (available.isNotEmpty) ...[
              const SizedBox(height: 34),
              SectionTitle(context.t('sources.available')),
              _Grid(sources: available),
            ],
          ]);
        },
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.sources});
  final List<MangaSource> sources;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final columns = (box.maxWidth / 340).floor().clamp(1, 4);
      const gap = 14.0;
      final w = (box.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(spacing: gap, runSpacing: gap, children: [
        for (var i = 0; i < sources.length; i++)
          SizedBox(width: w, child: Reveal(index: i, child: SourceTile(source: sources[i]))),
      ]);
    });
  }
}

class SourceTile extends StatelessWidget {
  const SourceTile({super.key, required this.source, this.onTap, this.showInstall = true});

  final MangaSource source;
  final VoidCallback? onTap;
  final bool showInstall;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final store = Services.i.sources;
    final installed = store.isInstalled(source);
    return Pressable(
      onTap: onTap,
      scale: 0.98,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: p.line)),
        child: Row(children: [
          SourceLogo(source, size: 48),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(source.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Txt.title(context)),
              const SizedBox(height: 4),
              Row(children: [
                Text(languageName(source.lang, context.isEn), style: Txt.caption(context)),
                const SizedBox(width: 10),
                _Popularity(value: source.popularity),
              ]),
            ]),
          ),
          if (showInstall) ...[
            const SizedBox(width: 10),
            AnimatedSwitcher(
              duration: Motion.fast,
              transitionBuilder: (child, a) => FadeTransition(opacity: a, child: ScaleTransition(scale: Tween(begin: 0.92, end: 1.0).animate(a), child: child)),
              child: installed
                  ? Pressable(
                      key: const ValueKey('remove'),
                      onTap: () => store.remove(source),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                        decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(11)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.check_rounded, size: 16, color: p.accent),
                          const SizedBox(width: 5),
                          Text(context.t('sources.installed'), style: Txt.caption(context).copyWith(color: p.text, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    )
                  : Pressable(
                      key: const ValueKey('install'),
                      onTap: () => store.install(source),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(color: p.accent, borderRadius: BorderRadius.circular(11)),
                        child: Text(context.t('sources.install'), style: Txt.caption(context).copyWith(color: p.bg, fontWeight: FontWeight.w700)),
                      ),
                    ),
            ),
          ],
        ]),
      ),
    );
  }
}

class _Popularity extends StatelessWidget {
  const _Popularity({required this.value});
  final int value;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final bars = (value / 20).ceil().clamp(1, 5);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 0; i < 5; i++)
        Container(
          width: 4,
          height: 6.0 + i * 2,
          margin: const EdgeInsets.only(right: 2),
          decoration: BoxDecoration(color: i < bars ? p.accent : p.surface2, borderRadius: BorderRadius.circular(2)),
        ),
    ]);
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Pressable(
      onTap: onTap,
      scale: 0.95,
      child: AnimatedContainer(
        duration: Motion.fast,
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? p.text : p.surface,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: selected ? p.text : p.line),
        ),
        child: Text(label, style: Txt.label(context).copyWith(fontSize: 13, color: selected ? p.bg : p.text2)),
      ),
    );
  }
}

class FilterChipButton extends _Chip {
  const FilterChipButton({required super.label, required super.selected, required super.onTap});
}
