import 'dart:async';

import 'package:flutter/material.dart';

import '../anilist/recommender.dart';
import '../core/l10n.dart';
import '../core/motion.dart';
import '../core/services.dart';
import '../core/theme.dart';
import 'manga_page.dart';
import 'shell.dart';
import 'widgets.dart';

class RecoPage extends StatefulWidget {
  const RecoPage({super.key});

  @override
  State<RecoPage> createState() => _RecoPageState();
}

class _RecoPageState extends State<RecoPage> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    Services.i.reco.onVisit();
    // Keeps the "new picks in 3 min" line honest.
    _tick = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reco = Services.i.reco;
    final pad = pagePadding(context);
    return Scaffold(
      body: ListenableBuilder(
        listenable: reco,
        builder: (context, _) {
          return CustomScrollView(slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(pad.left, pad.top, pad.right, 8),
              sliver: SliverToBoxAdapter(child: _header(context, reco)),
            ),
            if (reco.loading && reco.rows.isEmpty)
              SliverPadding(padding: EdgeInsets.symmetric(horizontal: pad.left), sliver: const SliverToBoxAdapter(child: _Loading()))
            else if (reco.error != null && reco.rows.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.wifi_off_rounded,
                  title: context.t('reco.error'),
                  action: AppButton(label: context.t('detail.retry'), tone: ButtonTone.quiet, onTap: reco.draw),
                ),
              )
            else
              SliverList.builder(
                itemCount: reco.rows.length,
                itemBuilder: (context, i) => _Row(
                  key: ValueKey('${reco.drawnAt?.millisecondsSinceEpoch}-${reco.rows[i].key}'),
                  row: reco.rows[i],
                  index: i,
                ),
              ),
            SliverToBoxAdapter(child: SizedBox(height: pad.bottom)),
          ]);
        },
      ),
    );
  }

  Widget _header(BuildContext context, Recommender reco) {
    final p = context.pal;
    final left = reco.remaining;
    final status = reco.isFresh
        ? '${context.t('reco.next')} ${left.inMinutes > 0 ? '${left.inMinutes} min' : '${left.inSeconds} s'}'
        : context.t('reco.ready');
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.t('reco.title'), style: Txt.display(context)),
            const SizedBox(height: 8),
            Text(context.t('reco.subtitle'), style: Txt.body(context)),
            const SizedBox(height: 4),
            Text(status, style: Txt.caption(context).copyWith(color: p.accent)),
          ]),
        ),
        const SizedBox(width: 16),
        AppButton(
          label: context.t('reco.refresh'),
          icon: Icons.casino_rounded,
          tone: ButtonTone.quiet,
          loading: reco.loading,
          onTap: reco.draw,
        ),
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({super.key, required this.row, required this.index});
  final RecoRow row;
  final int index;

  @override
  Widget build(BuildContext context) {
    final pad = pagePadding(context);
    final label = context.isEn ? row.labelEn : row.labelFr;
    return Reveal(
      index: index.clamp(0, 4),
      child: Padding(
        padding: const EdgeInsets.only(top: 26),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: EdgeInsets.symmetric(horizontal: pad.left), child: SectionTitle(label)),
          SizedBox(
            height: 270,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: pad.left),
              itemCount: row.items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 18),
              itemBuilder: (context, i) {
                final m = row.items[i];
                final tag = 'reco-${row.key}-${m.id}';
                return Reveal(
                  index: i,
                  step: 35,
                  offset: 10,
                  child: MangaCard(
                    title: m.title,
                    cover: m.cover,
                    heroTag: tag,
                    subtitle: [if (m.meanScore != null) '★ ${(m.meanScore! / 10).toStringAsFixed(1)}', ...m.genres.take(2)].join('  ·  '),
                    onTap: () => Navigator.of(context).push(SoftRoute(MangaPage.anilist(m, heroTag: tag))),
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(context.t('reco.loading'), style: Txt.caption(context)),
      for (var r = 0; r < 3; r++) ...[
        const SizedBox(height: 30),
        const Skeleton(width: 160, height: 20),
        const SizedBox(height: 16),
        SizedBox(
          height: 222,
          child: Row(children: [
            for (var i = 0; i < 6; i++) ...[
              const Skeleton(width: 148, height: 222),
              const SizedBox(width: 18),
            ],
          ]),
        ),
      ],
    ]);
  }
}

/// Exposed for the motion budget: rows animate once per draw, never on scroll.
const recoRevealBudget = Motion.enter;
