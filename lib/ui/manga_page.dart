import 'dart:math';

import 'package:flutter/material.dart';

import '../anilist/anilist.dart';
import '../core/activity.dart';
import '../core/l10n.dart';
import '../core/motion.dart';
import '../core/services.dart';
import '../core/theme.dart';
import '../sources/catalog.dart';
import '../sources/mangadex.dart';
import '../sources/source.dart';
import 'ink.dart';
import 'reader_page.dart';
import 'shell.dart';
import 'widgets.dart';

/// Manga page: cover, French synopsis, source to read with, chapters/volumes.
/// Opens from AniList (recommendations, profile), from a source search, or to resume.
class MangaPage extends StatefulWidget {
  const MangaPage._({this.ani, this.seed, this.resume, this.heroTag});

  factory MangaPage.anilist(AniMedia media, {Object? heroTag}) => MangaPage._(ani: media, heroTag: heroTag);
  factory MangaPage.source(SourceManga manga, {Object? heroTag}) => MangaPage._(seed: manga, heroTag: heroTag);
  factory MangaPage.resume(ReadEvent event) => MangaPage._(
        resume: event,
        seed: SourceManga(sourceId: event.sourceId, url: event.mangaUrl, title: event.title, cover: event.cover),
      );

  final AniMedia? ani;
  final SourceManga? seed;
  final ReadEvent? resume;
  final Object? heroTag;

  @override
  State<MangaPage> createState() => _MangaPageState();
}

class _MangaPageState extends State<MangaPage> {
  AniMedia? _ani;
  MangaSource? _source;
  SourceManga? _match;
  List<SourceManga> _candidates = [];
  List<Chapter>? _chapters;
  bool _loadingChapters = false;
  bool _notFound = false;
  Object? _chapterError;

  String? _summaryFr;
  String? _summaryEn;
  bool _translating = false;

  bool _volumes = false;
  bool _newestFirst = true;
  bool _expanded = false;
  int _generation = 0;

  String get _title => _ani?.title ?? widget.seed?.title ?? '';
  String? get _cover => _ani?.cover ?? _match?.cover ?? widget.seed?.cover;

  @override
  void initState() {
    super.initState();
    _ani = widget.ani;
    final seed = widget.seed;
    if (seed != null) {
      _source = sourceById(seed.sourceId);
    } else {
      final installed = Services.i.sources.installed;
      final fr = installed.where((s) => s.lang == 'fr');
      _source = fr.isNotEmpty ? fr.first : (installed.isNotEmpty ? installed.first : null);
    }
    final aniId = widget.ani?.id ?? widget.resume?.anilistId;
    if (aniId != null) _loadAni(aniId, summary: true);
    if (widget.ani == null) _probeAll();
    _loadSource();
  }

  Future<void> _loadAni(int id, {required bool summary}) async {
    try {
      final media = await Services.i.session.api.media(id);
      if (!mounted) return;
      final first = _ani == null || _probes.isEmpty;
      setState(() => _ani = media);
      if (first) _probeAll();
      if (!summary) return;
      _summaryEn ??= media.description;
      final fr = await MangaDex.descriptionFor(id, media.searchTitles, 'fr').catchError((_) => null);
      if (!mounted) return;
      setState(() => _summaryFr ??= (fr?.isNotEmpty ?? false) ? fr : null);
    } catch (_) {
      // The page still works from the source alone.
    }
  }

  void _autoTranslate() {
    if (_summaryFr == null && _summaryEn != null && !context.isEn && Services.i.translator.ready) _translateSummary();
  }

  Future<void> _translateSummary() async {
    final en = _summaryEn;
    if (en == null) return;
    setState(() => _translating = true);
    try {
      final fr = await Services.i.translator.text(en);
      if (mounted) setState(() => _summaryFr = fr);
    } catch (_) {
      // Keep the English synopsis.
    } finally {
      if (mounted) setState(() => _translating = false);
    }
  }

  Future<void> _loadSource({SourceManga? forced}) async {
    final source = _source;
    if (source == null) return;
    final generation = ++_generation;
    setState(() {
      _loadingChapters = true;
      _chapters = null;
      _chapterError = null;
      _notFound = false;
      if (forced == null) _match = null;
    });
    try {
      var match = forced;
      final seed = widget.seed;
      if (match == null && seed != null && seed.sourceId == source.id) match = seed;
      if (match == null && _ani != null) {
        match = await _find(source);
        if (match == null) _candidates = (await source.search(_ani!.searchTitles.first, 1, const {})).items;
      }
      if (generation != _generation) return;
      if (match == null) {
        setState(() {
          _notFound = true;
          _loadingChapters = false;
        });
        return;
      }
      setState(() => _match = match);

      final detailed = await source.details(match).catchError((_) => match!);
      if (generation != _generation || !mounted) return;
      setState(() => _match = detailed);
      _useSourceDetails(source, detailed);

      final chapters = await source.chapters(detailed);
      if (generation != _generation || !mounted) return;
      setState(() {
        _chapters = chapters;
        _loadingChapters = false;
      });
    } catch (e) {
      if (generation == _generation && mounted) {
        setState(() {
          _chapterError = e;
          _loadingChapters = false;
        });
      }
    }
  }

  void _useSourceDetails(MangaSource source, SourceManga m) {
    final desc = m.description?.trim();
    if (desc != null && desc.isNotEmpty) {
      if (source.lang == 'fr') {
        _summaryFr ??= desc;
      } else {
        _summaryEn ??= desc;
      }
    }
    if (widget.seed != null && widget.ani == null) Services.i.activity.logView(m.title, m.genres);
    // Link to AniList so reading progress syncs and the synopsis can be found in French.
    if (_ani == null) {
      if (m.anilistId != null) {
        _loadAni(m.anilistId!, summary: _summaryFr == null);
      } else {
        _guessAni(m);
      }
    }
    setState(() {});
  }

  Future<void> _guessAni(SourceManga m) async {
    try {
      final results = await Services.i.session.api.searchManga(m.title, perPage: 5);
      AniMedia? best;
      var bestScore = 0.0;
      for (final r in results) {
        for (final t in r.searchTitles) {
          final s = titleSimilarity(t, m.title);
          if (s > bestScore) {
            bestScore = s;
            best = r;
          }
        }
      }
      if (best != null && bestScore >= 0.85 && mounted) _loadAni(best.id, summary: _summaryFr == null);
    } catch (_) {}
  }

  /// Which installed sources carry this manga: null = still checking, else the match (or a miss).
  final _availability = <String, SourceManga?>{};
  final _checked = <String>{};
  final _probes = <String, Future<SourceManga?>>{};

  List<String> get _titles => _ani?.searchTitles ?? [if (widget.seed != null) widget.seed!.title];

  /// Looks the manga up in every installed source at once, to mark which ones have it.
  void _probeAll() {
    for (final s in Services.i.sources.installed) {
      if (widget.seed != null && widget.seed!.sourceId == s.id) {
        _availability[s.id] = widget.seed;
        _checked.add(s.id);
        continue;
      }
      _find(s).then((m) {
        if (mounted) setState(() => _checked.add(s.id));
      });
    }
  }

  Future<SourceManga?> _find(MangaSource source) => _probes[source.id] ??= _findInSource(source, _titles, aniId: _ani?.id)
      .then<SourceManga?>((m) => _availability[source.id] = m)
      .catchError((Object _) => _availability[source.id] = null);

  Future<SourceManga?> _findInSource(MangaSource source, List<String> titles, {int? aniId}) async {
    if (titles.isEmpty) return null;
    final candidates = <String, SourceManga>{};
    SourceManga? best;
    var bestScore = 0.0;
    for (final title in titles.take(3)) {
      final page = await source.search(title, 1, const {});
      for (final m in page.items) {
        candidates[m.url] = m;
        if (aniId != null && m.anilistId == aniId) return m;
        for (final t in [m.title, ...m.altTitles]) {
          for (final at in titles) {
            final s = titleSimilarity(t, at);
            if (s > bestScore) {
              bestScore = s;
              best = m;
            }
          }
        }
      }
      if (bestScore >= 0.9) break;
    }
    _candidates = candidates.values.toList();
    return bestScore >= 0.55 ? best : null;
  }

  Future<void> _pickMatch() async {
    final picked = await showModalBottomSheet<SourceManga>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _MatchSheet(source: _source!, initialQuery: _title, candidates: _candidates),
    );
    if (picked != null) _loadSource(forced: picked);
  }

  void _openReader(int index, {int page = 0}) {
    final chapters = _chapters;
    final source = _source;
    final match = _match;
    if (chapters == null || source == null || match == null || chapters.isEmpty) return;
    Navigator.of(context, rootNavigator: true).push(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) => ReaderPage(
        source: source,
        manga: match.cover == null ? match.copyWith(cover: _cover) : match,
        chapters: chapters,
        index: index,
        startPage: page,
        ani: _ani,
      ),
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: CurvedAnimation(parent: a, curve: Motion.easeOut), child: child),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListenableBuilder(
        listenable: Listenable.merge([Services.i.sources, Services.i.activity, Services.i.session]),
        builder: (context, _) => LayoutBuilder(builder: (context, box) {
          final wide = box.maxWidth >= 860;
          final pad = pagePadding(context);
          final scroll = CustomScrollView(slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(pad.left, pad.top - 8, pad.right, 0),
              sliver: SliverToBoxAdapter(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  IconCircle(icon: Icons.arrow_back_rounded, onTap: () => Navigator.of(context).maybePop(), tooltip: context.t('common.back')),
                  const SizedBox(height: 24),
                  wide
                      ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          SizedBox(width: 300, child: _coverColumn(context)),
                          const SizedBox(width: 80),
                          Expanded(child: _info(context)),
                        ])
                      : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            _coverArt(150),
                            const SizedBox(width: 20),
                            Expanded(child: _headline(context)),
                          ]),
                          const SizedBox(height: 20),
                          _actions(context),
                          const SizedBox(height: 26),
                          _body(context),
                        ]),
                  const SizedBox(height: 38),
                  _chaptersHeader(context),
                ]),
              ),
            ),
            ..._chapterSlivers(context, pad),
            SliverToBoxAdapter(child: SizedBox(height: pad.bottom + 20)),
          ]);
          if (!wide || _ani == null) return scroll;
          // The main character, inked on a red sun in the top-right corner.
          return Stack(children: [
            Positioned(
              right: 0,
              top: 0,
              width: 360,
              height: 330,
              child: IgnorePointer(child: FittedBox(fit: BoxFit.contain, alignment: Alignment.topRight, child: SizedBox(width: 430, height: 372, child: InkPortrait(mediaId: _ani!.id)))),
            ),
            scroll,
          ]);
        }),
      ),
    );
  }

  /// Cover laid on brush strokes, with the score slammed on as a red seal.
  Widget _coverArt(double width) {
    final score = _ani?.meanScore;
    return Stack(clipBehavior: Clip.none, children: [
      BrushCover(
        cover: _cover,
        headers: (_ani?.cover == null ? _source?.imageHeaders : null) ?? const {},
        title: _title,
        width: width,
      ),
      if (score != null)
        Positioned(
          right: -14,
          bottom: 18,
          child: OneShot(
            delay: const Duration(milliseconds: 700),
            builder: (context, t, child) {
              final a = (t / 0.6).clamp(0.0, 1.0), b = ((t - 0.6) / 0.4).clamp(0.0, 1.0);
              final s = t < 0.6 ? 2.2 - 1.28 * a : 0.92 + 0.08 * b;
              return Opacity(opacity: a, child: Transform.rotate(angle: (t < 0.6 ? -24 + 16 * a : -8 - 2 * b) * pi / 180, child: Transform.scale(scale: s, child: child)));
            },
            child: Container(
              width: width * 0.3,
              height: width * 0.3,
              decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xE6F2EBDD), border: Border.all(color: inkRed, width: 4)),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(context.isEn ? 'SCORE' : 'NOTE', style: Txt.tag(context).copyWith(fontSize: 10, color: inkRed, letterSpacing: 1)),
                Text((score / 10).toStringAsFixed(1).replaceAll('.', ','), style: Txt.number(context, size: width * 0.1).copyWith(color: inkRed)),
              ]),
            ),
          ),
        ),
    ]);
  }

  Widget _coverColumn(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(left: 10), child: _coverArt(280)),
        const SizedBox(height: 30),
        _actions(context),
      ]);

  Widget _info(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _headline(context),
        const SizedBox(height: 26),
        _body(context),
      ]);

  Widget _headline(BuildContext context) {
    final p = context.pal;
    final ani = _ani;
    final authors = ani?.authors.isNotEmpty == true ? ani!.authors : (_match?.authors ?? const <String>[]);
    final status = _statusLabel(context);
    final meta = [
      if (authors.isNotEmpty) '${context.t('detail.by')} ${authors.take(2).join(', ')}',
      if (ani?.year != null) '${ani!.year}',
      ?status,
      if (ani?.chapters != null) '${ani!.chapters} ${context.t('detail.chaptersCount')}',
    ];
    final genres = (ani?.genres.isNotEmpty == true ? ani!.genres : _match?.genres ?? const <String>[]).take(6).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Reveal(child: Padding(padding: const EdgeInsets.only(right: 260), child: Text(_title, style: Txt.display(context).copyWith(fontSize: 52)))),
      if (ani?.native != null && ani!.native != _title) ...[
        const SizedBox(height: 4),
        Text(ani.native!, style: Txt.caption(context).copyWith(fontSize: 14)),
      ],
      const SizedBox(height: 10),
      if (meta.isNotEmpty) Reveal(index: 1, child: Text(meta.join('  ·  '), style: Txt.caption(context).copyWith(fontSize: 13.5, color: p.text2))),
      if (ani?.meanScore != null) ...[
        const SizedBox(height: 10),
        Reveal(
          index: 1,
          child: Row(children: [
            for (var i = 0; i < 5; i++)
              Icon(
                i < (ani!.meanScore! / 20).round() ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 17,
                color: p.star,
              ),
            const SizedBox(width: 8),
            Text((ani!.meanScore! / 10).toStringAsFixed(1), style: Txt.label(context).copyWith(color: p.text2)),
          ]),
        ),
      ],
      if (genres.isNotEmpty) ...[
        const SizedBox(height: 16),
        Reveal(
          index: 2,
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            for (final (i, g) in genres.indexed)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: i == 0 ? inkBlack : Colors.transparent, border: Border.all(color: inkBlack, width: 2)),
                child: Text(g, style: Txt.label(context).copyWith(fontSize: 12, color: i == 0 ? inkPaper : inkBlack)),
              ),
          ]),
        ),
      ],
    ]);
  }

  String? _statusLabel(BuildContext context) {
    final s = _ani?.status;
    if (s != null) {
      return switch (s) {
        'RELEASING' => context.t('detail.ongoing'),
        'FINISHED' => context.t('detail.finished'),
        'HIATUS' => context.t('detail.hiatus'),
        'CANCELLED' => context.t('detail.cancelled'),
        _ => null,
      };
    }
    return switch (_match?.status) {
      MangaStatus.ongoing => context.t('detail.ongoing'),
      MangaStatus.completed => context.t('detail.finished'),
      MangaStatus.hiatus => context.t('detail.hiatus'),
      MangaStatus.cancelled => context.t('detail.cancelled'),
      _ => null,
    };
  }

  ReadEvent? get _lastRead {
    final s = _source, m = _match;
    if (s == null || m == null) return null;
    return Services.i.activity.lastRead(s.id, m.url);
  }

  Widget _actions(BuildContext context) {
    final chapters = _chapters;
    final last = _lastRead;
    final session = Services.i.session;
    final ani = _ani;
    final inList = ani != null && session.entryFor(ani.id) != null;
    var resumeIndex = -1;
    if (last != null && chapters != null) resumeIndex = chapters.indexWhere((c) => c.url == last.chapterUrl);
    // Without in-app history, pick up after the AniList progress.
    if (resumeIndex < 0 && chapters != null && ani != null) {
      final progress = session.entryFor(ani.id)?.progress ?? 0;
      if (progress > 0) resumeIndex = chapters.indexWhere((c) => (c.number ?? 0) > progress);
    }
    final canRead = chapters != null && chapters.isNotEmpty;
    final resuming = resumeIndex >= 0 && canRead;
    final sub = resuming
        ? '${chapters[resumeIndex].name}${last?.chapterUrl == chapters[resumeIndex].url ? ' · ${context.t('reader.page').toLowerCase()} ${last!.page + 1}' : ''}'
        : (canRead ? chapters.first.name : (_loadingChapters ? context.t('detail.searching') : ''));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Pressable(
        enabled: canRead,
        onTap: canRead
            ? () => resuming
                ? _openReader(resumeIndex, page: last?.chapterUrl == chapters[resumeIndex].url ? last!.page : 0)
                : _openReader(0)
            : null,
        child: AnimatedOpacity(
          duration: Motion.fast,
          opacity: canRead ? 1 : 0.5,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const EnsoButton(size: 76, delay: Duration(milliseconds: 500)),
            const SizedBox(width: 14),
            Flexible(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(resuming ? context.t('detail.continue') : context.t('detail.read'), style: Txt.h2(context).copyWith(fontSize: 26, height: 1)),
                const SizedBox(height: 3),
                Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: Txt.label(context).copyWith(fontSize: 13, color: context.pal.text2)),
              ]),
            ),
          ]),
        ),
      ),
      if (ani != null && session.canWrite) ...[
        const SizedBox(height: 16),
        Pressable(
          onTap: inList ? null : () => session.addToPlan(ani),
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: inList ? inkBlack : Colors.transparent, border: Border.all(color: inkBlack, width: 2)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(inList ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, size: 18, color: inList ? inkPaper : inkBlack),
              const SizedBox(width: 8),
              Text(inList ? context.t('detail.inPlan') : context.t('detail.addPlan'), style: Txt.label(context).copyWith(color: inList ? inkPaper : inkBlack)),
            ]),
          ),
        ),
      ],
    ]);
  }

  Widget _body(BuildContext context) {
    final p = context.pal;
    final summary = _summaryFr ?? _summaryEn;
    final english = _summaryFr == null && _summaryEn != null && !context.isEn;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(context.t('detail.summary'), style: Txt.h2(context)),
      const SizedBox(height: 12),
      if (summary == null)
        const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Skeleton(height: 14, width: 520),
          SizedBox(height: 10),
          Skeleton(height: 14, width: 460),
          SizedBox(height: 10),
          Skeleton(height: 14, width: 300),
        ])
      else ...[
        AnimatedSize(
          duration: Motion.base,
          curve: Motion.easeOut,
          alignment: Alignment.topCenter,
          child: Text(
            summary,
            maxLines: _expanded ? null : 6,
            overflow: _expanded ? null : TextOverflow.fade,
            style: Txt.body(context).copyWith(fontSize: 15, color: p.text.withValues(alpha: 0.82)),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 18, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          if (summary.length > 380)
            Pressable(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Text(
                _expanded ? (context.isEn ? 'Show less' : 'Réduire') : (context.isEn ? 'Read more' : 'Lire la suite'),
                style: Txt.label(context).copyWith(color: p.accent),
              ),
            ),
          if (english) ...[
            Text(context.t('detail.summaryEn'), style: Txt.caption(context)),
            if (Services.i.translator.ready)
              Pressable(
                onTap: _translating ? null : _translateSummary,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (_translating)
                    SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: p.accent))
                  else
                    Icon(Icons.translate_rounded, size: 16, color: p.accent),
                  const SizedBox(width: 6),
                  Text(context.t('detail.translateSummary'), style: Txt.label(context).copyWith(color: p.accent)),
                ]),
              ),
          ],
        ]),
      ],
      const SizedBox(height: 32),
      Text(context.t('detail.source'), style: Txt.h2(context)),
      const SizedBox(height: 14),
      _sourcePicker(context),
    ]);
  }

  Widget _sourcePicker(BuildContext context) {
    final p = context.pal;
    final installed = Services.i.sources.installed;
    if (installed.isEmpty) {
      return Row(children: [
        Expanded(child: Text(context.t('detail.noSource'), style: Txt.body(context))),
        AppButton(label: context.t('nav.sources'), tone: ButtonTone.accent, onTap: () => ShellScope.of(context).select(3)),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 10, runSpacing: 10, children: [
        for (final s in installed)
          Pressable(
            onTap: () {
              if (_source?.id == s.id) return;
              setState(() => _source = s);
              _loadSource();
            },
            child: AnimatedContainer(
              duration: Motion.fast,
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: _source?.id == s.id ? inkBlack : Colors.transparent,
                border: Border.all(color: inkBlack, width: 2),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                _AvailabilityDot(checked: _checked.contains(s.id), found: _availability[s.id] != null),
                const SizedBox(width: 8),
                Text(s.name, style: Txt.label(context).copyWith(color: _source?.id == s.id ? inkPaper : inkBlack)),
                const SizedBox(width: 6),
                Text(s.lang.toUpperCase(), style: Txt.caption(context).copyWith(color: _source?.id == s.id ? const Color(0xFFCFC6B5) : null)),
              ]),
            ),
          ),
      ]),
      const SizedBox(height: 12),
      if (_match != null && widget.seed?.url != _match!.url)
        Row(children: [
          Flexible(
            child: Text('${context.t('detail.match')} ${_match!.title}', maxLines: 1, overflow: TextOverflow.ellipsis, style: Txt.caption(context)),
          ),
          const SizedBox(width: 10),
          Pressable(
            onTap: _pickMatch,
            child: Container(
              padding: const EdgeInsets.only(bottom: 1),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: inkRed, width: 2))),
              child: Text(context.t('detail.changeMatch'), style: Txt.caption(context).copyWith(color: inkBlack, fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
    ]);
  }

  Widget _chaptersHeader(BuildContext context) {
    final count = _chapters?.length;
    Widget tab(String label, bool active, VoidCallback onTap) => Pressable(
          onTap: onTap,
          child: SizedBox(
            height: 44,
            child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
              if (active) const Positioned(left: -4, right: -4, bottom: 4, child: InkUnderline()),
              Text(label, style: Txt.h2(context).copyWith(fontSize: 20, fontWeight: active ? FontWeight.w800 : FontWeight.w500)),
            ]),
          ),
        );
    return Container(
      padding: const EdgeInsets.only(bottom: 4),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: inkBlack, width: 2))),
      child: Row(children: [
        tab(context.t('detail.chapters'), !_volumes, () => setState(() => _volumes = false)),
        const SizedBox(width: 20),
        tab(context.t('detail.volumes'), _volumes, () => setState(() => _volumes = true)),
        if (count != null) ...[const SizedBox(width: 14), Text('$count', style: Txt.label(context).copyWith(color: context.pal.text3))],
        const Spacer(),
        if (count != null && count > 0)
          Pressable(
            onTap: () => setState(() => _newestFirst = !_newestFirst),
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(border: Border.all(color: inkBlack, width: 2)),
              child: Row(children: [
                Icon(_newestFirst ? Icons.south_rounded : Icons.north_rounded, size: 16, color: inkBlack),
                const SizedBox(width: 6),
                Text(_newestFirst ? context.t('detail.newest') : context.t('detail.oldest'), style: Txt.label(context)),
              ]),
            ),
          ),
      ]),
    );
  }

  List<Widget> _chapterSlivers(BuildContext context, EdgeInsets pad) {
    final p = context.pal;
    Widget boxed(Widget child) => SliverPadding(
          padding: EdgeInsets.fromLTRB(pad.left, 18, pad.right, 0),
          sliver: SliverToBoxAdapter(child: child),
        );
    if (_source == null) return [];
    if (_notFound) {
      return [
        boxed(Row(children: [
          Expanded(child: Text(context.t('detail.notFound'), style: Txt.body(context))),
          AppButton(label: context.t('detail.pickMatch'), tone: ButtonTone.quiet, onTap: _pickMatch),
        ])),
      ];
    }
    if (_chapterError != null) {
      return [
        boxed(Row(children: [
          Expanded(child: Text(context.t('detail.error'), style: Txt.body(context))),
          AppButton(label: context.t('detail.retry'), tone: ButtonTone.quiet, onTap: () => _loadSource(forced: _match)),
        ])),
      ];
    }
    final chapters = _chapters;
    if (chapters == null) {
      return [
        boxed(Column(children: [
          Row(children: [
            SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: p.accent)),
            const SizedBox(width: 10),
            Text(context.t('detail.searching'), style: Txt.caption(context)),
          ]),
          const SizedBox(height: 16),
          for (var i = 0; i < 5; i++) ...[const Skeleton(height: 58), const SizedBox(height: 8)],
        ])),
      ];
    }
    if (chapters.isEmpty) return [boxed(Text(context.t('detail.noChapters'), style: Txt.body(context)))];

    final progress = _ani == null ? 0 : (Services.i.session.entryFor(_ani!.id)?.progress ?? 0);
    final lastUrl = _lastRead?.chapterUrl;
    final order = List.generate(chapters.length, (i) => i);
    if (_newestFirst) order.setAll(0, order.reversed.toList());

    final rows = <Widget>[];
    String? currentVolume;
    for (final i in order) {
      final c = chapters[i];
      if (_volumes) {
        final v = (c.volume == null || c.volume!.isEmpty) ? null : c.volume;
        if (rows.isEmpty || v != currentVolume) {
          currentVolume = v;
          rows.add(Padding(
            padding: EdgeInsets.only(top: rows.isEmpty ? 0 : 22, bottom: 8, left: 4),
            child: Text(v == null ? context.t('detail.noVolume') : '${context.t('detail.volume')} $v', style: Txt.label(context).copyWith(color: p.text3)),
          ));
        }
      }
      final read = (c.number != null && c.number! <= progress) ;
      rows.add(_ChapterRow(
        chapter: c,
        read: read,
        current: c.url == lastUrl,
        onTap: () => _openReader(i, page: c.url == lastUrl ? (_lastRead?.page ?? 0) : 0),
      ));
    }
    return [
      SliverPadding(
        padding: EdgeInsets.fromLTRB(pad.left, 16, pad.right, 0),
        sliver: SliverList.builder(itemCount: rows.length, itemBuilder: (_, i) => rows[i]),
      ),
    ];
  }
}

class _ChapterRow extends StatelessWidget {
  const _ChapterRow({required this.chapter, required this.read, required this.current, required this.onTap});

  final Chapter chapter;
  final bool read, current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final sub = [
      if (chapter.title != null) chapter.title!,
      if (chapter.scanlator != null) chapter.scanlator!,
      if (chapter.date != null) context.ago(chapter.date!),
    ].join('  ·  ');
    return Padding(
      padding: EdgeInsets.zero,
      child: Pressable(
        scale: 0.99,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: current ? const Color(0xFFEAE2D1) : Colors.transparent,
            border: const Border(bottom: BorderSide(color: Color(0x33121010))),
          ),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(chapter.name, style: Txt.title(context).copyWith(color: read ? p.text3 : p.text)),
                if (sub.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: Txt.caption(context)),
                ],
              ]),
            ),
            if (current) Pill(context.isEn ? 'Reading' : 'En cours', icon: Icons.play_arrow_rounded),
            if (read && !current) Icon(Icons.check_rounded, size: 18, color: p.text3),
          ]),
        ),
      ),
    );
  }
}

/// Lets the user pick the right title when the automatic match failed or was wrong.
class _MatchSheet extends StatefulWidget {
  const _MatchSheet({required this.source, required this.initialQuery, required this.candidates});
  final MangaSource source;
  final String initialQuery;
  final List<SourceManga> candidates;

  @override
  State<_MatchSheet> createState() => _MatchSheetState();
}

class _MatchSheetState extends State<_MatchSheet> {
  late final _q = TextEditingController(text: widget.initialQuery);
  late List<SourceManga> _items = widget.candidates;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (_items.isEmpty) _search();
  }

  Future<void> _search() async {
    setState(() => _loading = true);
    try {
      final r = await widget.source.search(_q.text, 1, const {});
      if (mounted) setState(() => _items = r.items);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 820, maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 12),
          decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(28)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(context.t('detail.pickMatch'), style: Txt.h2(context)),
            const SizedBox(height: 14),
            TextField(
              controller: _q,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                filled: true,
                fillColor: p.surface2,
                prefixIcon: Icon(Icons.search_rounded, color: p.text3),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : GridView.builder(
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 140,
                        mainAxisSpacing: 18,
                        crossAxisSpacing: 14,
                        childAspectRatio: 0.5,
                      ),
                      itemCount: _items.length,
                      itemBuilder: (context, i) => MangaCard(
                        width: double.infinity,
                        title: _items[i].title,
                        cover: _items[i].cover,
                        headers: widget.source.imageHeaders,
                        onTap: () => Navigator.pop(context, _items[i]),
                      ),
                    ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Small marker on a source chip: spinner while checking, green dot if the manga is there, grey cross if not.
class _AvailabilityDot extends StatelessWidget {
  const _AvailabilityDot({required this.checked, required this.found});
  final bool checked, found;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return AnimatedSwitcher(
      duration: Motion.fast,
      transitionBuilder: (child, a) => ScaleTransition(scale: a, child: FadeTransition(opacity: a, child: child)),
      child: !checked
          ? SizedBox(key: const ValueKey('wait'), width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.4, color: p.text3))
          : found
              ? Container(
                  key: const ValueKey('yes'),
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3FD18B),
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: const Color(0xFF3FD18B).withValues(alpha: 0.5), blurRadius: 6)],
                  ),
                )
              : Icon(Icons.close_rounded, key: const ValueKey('no'), size: 12, color: p.text3),
    );
  }
}
