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
    _loadSource();
  }

  Future<void> _loadAni(int id, {required bool summary}) async {
    try {
      final media = await Services.i.session.api.media(id);
      if (!mounted) return;
      setState(() => _ani = media);
      if (!summary) return;
      _summaryEn ??= media.description;
      final fr = await MangaDex.descriptionFor(id, media.searchTitles, 'fr').catchError((_) => null);
      if (!mounted) return;
      setState(() => _summaryFr ??= (fr?.isNotEmpty ?? false) ? fr : null);
      _autoTranslate();
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
      if (match == null && _ani != null) match = await _findInSource(source, _ani!);
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
    _autoTranslate();
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

  Future<SourceManga?> _findInSource(MangaSource source, AniMedia ani) async {
    final candidates = <String, SourceManga>{};
    SourceManga? best;
    var bestScore = 0.0;
    for (final title in ani.searchTitles.take(3)) {
      final page = await source.search(title, 1, const {});
      for (final m in page.items) {
        candidates[m.url] = m;
        if (m.anilistId == ani.id) return m;
        for (final t in [m.title, ...m.altTitles]) {
          for (final at in ani.searchTitles) {
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
          return CustomScrollView(slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(pad.left, pad.top - 8, pad.right, 0),
              sliver: SliverToBoxAdapter(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  IconCircle(icon: Icons.arrow_back_rounded, onTap: () => Navigator.of(context).maybePop(), tooltip: context.t('common.back')),
                  const SizedBox(height: 24),
                  wide
                      ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          SizedBox(width: 264, child: _coverColumn(context)),
                          const SizedBox(width: 44),
                          Expanded(child: _info(context)),
                        ])
                      : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            SizedBox(width: 150, child: AspectRatio(aspectRatio: 2 / 3, child: _coverArt())),
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
        }),
      ),
    );
  }

  Widget _coverArt() => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color(0x4D000000), blurRadius: 30, offset: Offset(0, 16))],
        ),
        child: CoverImage(
          url: _cover,
          headers: (_ani?.cover == null ? _source?.imageHeaders : null) ?? const {},
          radius: 16,
          heroTag: widget.heroTag,
          title: _title,
        ),
      );

  Widget _coverColumn(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        AspectRatio(aspectRatio: 2 / 3, child: _coverArt()),
        const SizedBox(height: 22),
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
      Reveal(child: Text(_title, style: Txt.h1(context).copyWith(fontSize: 30, letterSpacing: -0.7))),
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
        Reveal(index: 2, child: Wrap(spacing: 8, runSpacing: 8, children: [for (final g in genres) Pill(g)])),
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
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AppButton(
        expand: true,
        icon: Icons.menu_book_rounded,
        label: resumeIndex >= 0 && canRead
            ? '${context.t('detail.continue')} · ${chapters[resumeIndex].name}'
            : context.t('detail.read'),
        loading: _loadingChapters,
        onTap: canRead
            ? () => resumeIndex >= 0
                ? _openReader(resumeIndex, page: last?.chapterUrl == chapters[resumeIndex].url ? last!.page : 0)
                : _openReader(0)
            : null,
      ),
      if (ani != null && session.canWrite) ...[
        const SizedBox(height: 10),
        AppButton(
          expand: true,
          tone: ButtonTone.quiet,
          icon: inList ? Icons.bookmark_added_rounded : Icons.bookmark_add_outlined,
          label: inList ? context.t('detail.inPlan') : context.t('detail.addPlan'),
          onTap: inList ? null : () => session.addToPlan(ani),
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
              padding: const EdgeInsets.fromLTRB(8, 8, 14, 8),
              decoration: BoxDecoration(
                color: _source?.id == s.id ? p.accentSoft : p.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _source?.id == s.id ? p.accent : p.line, width: 1.2),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                SourceLogo(s, size: 28),
                const SizedBox(width: 10),
                Text(s.name, style: Txt.label(context)),
                const SizedBox(width: 6),
                Text(s.lang.toUpperCase(), style: Txt.caption(context)),
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
          Pressable(onTap: _pickMatch, child: Text(context.t('detail.changeMatch'), style: Txt.caption(context).copyWith(color: p.accent, fontWeight: FontWeight.w700))),
        ]),
    ]);
  }

  Widget _chaptersHeader(BuildContext context) {
    final count = _chapters?.length;
    return Row(children: [
      Text(context.t('detail.chapters'), style: Txt.h2(context)),
      if (count != null) ...[const SizedBox(width: 10), Pill('$count')],
      const Spacer(),
      if (count != null && count > 0) ...[
        SizedBox(
          width: 220,
          child: Segmented<bool>(
            value: _volumes,
            options: [(false, context.t('detail.chapters')), (true, context.t('detail.volumes'))],
            onChanged: (v) => setState(() => _volumes = v),
          ),
        ),
        const SizedBox(width: 10),
        IconCircle(
          icon: _newestFirst ? Icons.south_rounded : Icons.north_rounded,
          tooltip: _newestFirst ? context.t('detail.newest') : context.t('detail.oldest'),
          onTap: () => setState(() => _newestFirst = !_newestFirst),
        ),
      ],
    ]);
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
      padding: const EdgeInsets.only(bottom: 6),
      child: Pressable(
        scale: 0.99,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: current ? p.accentSoft : p.surface,
            borderRadius: BorderRadius.circular(14),
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
