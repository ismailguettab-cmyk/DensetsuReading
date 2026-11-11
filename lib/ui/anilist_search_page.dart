import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../anilist/anilist.dart';
import '../core/l10n.dart';
import '../core/motion.dart';
import '../core/services.dart';
import '../core/theme.dart';
import 'ink.dart';
import 'manga_page.dart';
import 'shell.dart';
import 'widgets.dart';

/// One choice in a filter: AniList value (null = any) and its FR / EN labels.
typedef _Opt<T> = (T?, String, String);

const _statuses = <_Opt<String>>[
  (null, 'Tous', 'All'),
  ('RELEASING', 'En cours', 'Releasing'),
  ('FINISHED', 'Terminé', 'Finished'),
  ('HIATUS', 'En pause', 'Hiatus'),
  ('CANCELLED', 'Annulé', 'Cancelled'),
  ('NOT_YET_RELEASED', 'À paraître', 'Not yet released'),
];

const _genres = <(String, String, String)>[
  ('Action', 'Action', 'Action'),
  ('Adventure', 'Aventure', 'Adventure'),
  ('Comedy', 'Comédie', 'Comedy'),
  ('Drama', 'Drame', 'Drama'),
  ('Ecchi', 'Ecchi', 'Ecchi'),
  ('Fantasy', 'Fantasy', 'Fantasy'),
  ('Horror', 'Horreur', 'Horror'),
  ('Mahou Shoujo', 'Magical girl', 'Mahou shoujo'),
  ('Mecha', 'Mecha', 'Mecha'),
  ('Music', 'Musique', 'Music'),
  ('Mystery', 'Mystère', 'Mystery'),
  ('Psychological', 'Psychologique', 'Psychological'),
  ('Romance', 'Romance', 'Romance'),
  ('Sci-Fi', 'Science-fiction', 'Sci-fi'),
  ('Slice of Life', 'Tranche de vie', 'Slice of life'),
  ('Sports', 'Sport', 'Sports'),
  ('Supernatural', 'Surnaturel', 'Supernatural'),
  ('Thriller', 'Thriller', 'Thriller'),
];

const _audiences = <_Opt<String>>[
  (null, 'Tous', 'All'),
  ('Shounen', 'Shōnen', 'Shōnen'),
  ('Seinen', 'Seinen', 'Seinen'),
  ('Shoujo', 'Shōjo', 'Shōjo'),
  ('Josei', 'Josei', 'Josei'),
];

const _scores = <_Opt<int>>[
  (null, 'Toutes', 'Any'),
  (60, '6+', '6+'),
  (70, '7+', '7+'),
  (80, '8+', '8+'),
  (85, '8,5+', '8.5+'),
];

/// Publication years: (from, to) or null for any.
const _years = <_Opt<(int?, int?)>>[
  (null, 'Toutes', 'Any'),
  ((2020, null), '2020 et après', '2020 and later'),
  ((2010, 2019), '2010 – 2019', '2010 – 2019'),
  ((2000, 2009), '2000 – 2009', '2000 – 2009'),
  ((1990, 1999), '1990 – 1999', '1990 – 1999'),
  ((null, 1989), 'Avant 1990', 'Before 1990'),
];

const _countries = <_Opt<String>>[
  (null, 'Toutes', 'All'),
  ('JP', 'Japon (manga)', 'Japan (manga)'),
  ('KR', 'Corée (manhwa)', 'Korea (manhwa)'),
  ('CN', 'Chine (manhua)', 'China (manhua)'),
];

const _formats = <_Opt<String>>[
  (null, 'Tous', 'All'),
  ('MANGA', 'Série', 'Series'),
  ('ONE_SHOT', 'One-shot', 'One-shot'),
];

const _sorts = <(String, String, String)>[
  ('POPULARITY_DESC', 'Popularité', 'Popularity'),
  ('TRENDING_DESC', 'Tendance', 'Trending'),
  ('SCORE_DESC', 'Note', 'Score'),
  ('START_DATE_DESC', 'Récents', 'Newest'),
  ('TITLE_ROMAJI', 'A → Z', 'A → Z'),
];

/// Search (day mode): the whole AniList catalogue, by name, by filters or both, like
/// AniList's own browse page. A result opens the manga page, where the source is chosen.
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _query = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;

  String? _status, _audience, _country, _format;
  final _genresOn = <String>{};
  int? _minScore;
  (int?, int?)? _year;
  String _sort = 'POPULARITY_DESC';

  final _items = <AniMedia>[];
  int _page = 1;
  bool _hasNext = true;
  bool _loading = false;
  Object? _error;
  int _generation = 0;
  DateTime _shownAt = DateTime.now();

  bool get _filtered =>
      _status != null || _audience != null || _country != null || _format != null || _genresOn.isNotEmpty || _minScore != null || _year != null;

  /// The page is rebuilt each time the tab comes back (so its entrance replays):
  /// the search, filters and results are kept here in between.
  static _SearchPageState? _last;
  String _savedQuery = '';

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 900) _load();
    });
    final last = _last;
    if (last != null && last._items.isNotEmpty) {
      _query.text = last._savedQuery;
      _status = last._status;
      _audience = last._audience;
      _country = last._country;
      _format = last._format;
      _genresOn.addAll(last._genresOn);
      _minScore = last._minScore;
      _year = last._year;
      _sort = last._sort;
      _items.addAll(last._items);
      _page = last._page;
      _hasNext = last._hasNext;
    } else {
      _reset();
    }
  }

  @override
  void dispose() {
    _savedQuery = _query.text;
    _last = this;
    _debounce?.cancel();
    _scroll.dispose();
    _query.dispose();
    super.dispose();
  }

  void _onType(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 380), () {
      Services.i.activity.logSearch(_query.text);
      _reset();
    });
  }

  void _change(VoidCallback f) {
    setState(f);
    _reset();
  }

  void _clearFilters() => _change(() {
        _status = _audience = _country = _format = null;
        _genresOn.clear();
        _minScore = null;
        _year = null;
      });

  void _reset() {
    _generation++;
    setState(() {
      _items.clear();
      _page = 1;
      _hasNext = true;
      _error = null;
      _loading = false;
      _shownAt = DateTime.now();
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
    _load();
  }

  /// Loads the next page; called again as the grid nears its end (lazy loading).
  Future<void> _load() async {
    if (_loading || !_hasNext) return;
    final generation = _generation;
    setState(() => _loading = true);
    try {
      final (items, more) = await Services.i.session.api.browse(
        page: _page,
        search: _query.text,
        status: _status,
        genres: _genresOn.toList(),
        tag: _audience,
        country: _country,
        format: _format,
        minScore: _minScore,
        yearFrom: _year?.$1,
        yearTo: _year?.$2,
        sort: _sort,
      );
      if (generation != _generation || !mounted) return;
      final seen = {for (final m in _items) m.id};
      setState(() {
        _items.addAll(items.where((m) => seen.add(m.id)));
        _hasNext = more;
        _page++;
        _loading = false;
      });
    } catch (e) {
      if (generation != _generation || !mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  String _label<T>(List<_Opt<T>> opts, T? value) {
    final o = opts.firstWhere((o) => o.$1 == value, orElse: () => opts.first);
    return context.isEn ? o.$3 : o.$2;
  }

  @override
  Widget build(BuildContext context) {
    final pad = pagePadding(context);
    final en = context.isEn;
    final wide = MediaQuery.sizeOf(context).width >= 820;
    return Scaffold(
      body: CustomScrollView(controller: _scroll, slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(pad.left, pad.top, pad.right, 0),
          sliver: SliverToBoxAdapter(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Reveal(child: Text(context.t('search.title'), style: Txt.display(context).copyWith(fontSize: wide ? 54 : 42))),
              const SizedBox(height: 6),
              Reveal(
                index: 1,
                child: Text(
                  en ? 'Every manga on AniList: by name, by filters, or both.' : 'Tout le catalogue AniList : par nom, par filtres, ou les deux.',
                  style: Txt.body(context).copyWith(fontSize: 16),
                ),
              ),
              const SizedBox(height: 22),
              Reveal(index: 2, child: _searchBar(context)),
              const SizedBox(height: 16),
              Reveal(index: 3, child: _filterBar(context)),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.only(bottom: 8),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: inkBlack, width: 2))),
                child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, runSpacing: 10, children: [
                  Text(
                    _query.text.trim().isNotEmpty || _filtered ? context.t('search.results') : (en ? 'Popular right now' : 'Les plus populaires'),
                    style: Txt.h2(context).copyWith(fontSize: 24),
                  ),
                  if (_loading && _items.isEmpty) const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: inkRed)),
                  const SizedBox(width: 12),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(en ? 'Sort by' : 'Trier par', style: Txt.body(context).copyWith(fontSize: 14, color: context.pal.text3)),
                    const SizedBox(width: 10),
                    for (final (v, fr, enLabel) in _sorts)
                      _Segment(label: en ? enLabel : fr, active: _sort == v, onTap: () {
                        if (_sort != v) _change(() => _sort = v);
                      }),
                  ]),
                ]),
              ),
              const SizedBox(height: 20),
            ]),
          ),
        ),
        ..._results(context, pad),
      ]),
    );
  }

  Widget _searchBar(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFBF8F1),
        border: Border.fromBorderSide(BorderSide(color: inkBlack, width: 2)),
        boxShadow: [BoxShadow(color: inkBlack, offset: Offset(6, 6))],
      ),
      child: Row(children: [
        const Padding(padding: EdgeInsets.only(left: 16, right: 6), child: Icon(Icons.search_rounded, color: inkBlack, size: 24)),
        Expanded(
          child: TextField(
            controller: _query,
            onChanged: _onType,
            onSubmitted: (_) {
              _debounce?.cancel();
              Services.i.activity.logSearch(_query.text);
              _reset();
            },
            textInputAction: TextInputAction.search,
            style: Txt.label(context).copyWith(fontSize: 17, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: context.isEn ? 'Title, in any language…' : 'Titre, dans n’importe quelle langue…',
              hintStyle: Txt.label(context).copyWith(fontSize: 17, fontWeight: FontWeight.w500, color: const Color(0xFF6B6359)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 18),
            ),
          ),
        ),
        ListenableBuilder(
          listenable: _query,
          builder: (context, _) => _query.text.isEmpty
              ? const SizedBox(width: 12)
              : IconButton(
                  tooltip: context.isEn ? 'Clear' : 'Effacer',
                  icon: const Icon(Icons.close_rounded, color: inkBlack),
                  onPressed: () {
                    _query.clear();
                    _reset();
                  },
                ),
        ),
      ]),
    );
  }

  /// AniList-style filter row: each button opens its list; active ones turn ink black.
  Widget _filterBar(BuildContext context) {
    final en = context.isEn;
    final genreLabel = _genresOn.isEmpty
        ? (en ? 'All' : 'Toutes')
        : _genresOn.length == 1
            ? _genres.firstWhere((g) => g.$1 == _genresOn.first).$2
            : '${_genresOn.length} ${en ? 'selected' : 'choisies'}';
    return Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
      _Dropdown<String>(
        title: en ? 'Status' : 'Statut',
        value: _label(_statuses, _status),
        active: _status != null,
        options: _statuses,
        selected: (v) => v == _status,
        onPick: (v) => _change(() => _status = v),
      ),
      _GenreDropdown(
        title: en ? 'Genres' : 'Catégories',
        value: genreLabel,
        selected: _genresOn,
        onToggle: (g) => _change(() => _genresOn.contains(g) ? _genresOn.remove(g) : _genresOn.add(g)),
        onClear: () => _change(_genresOn.clear),
      ),
      _Dropdown<String>(
        title: en ? 'Audience' : 'Public',
        value: _label(_audiences, _audience),
        active: _audience != null,
        options: _audiences,
        selected: (v) => v == _audience,
        onPick: (v) => _change(() => _audience = v),
      ),
      _Dropdown<int>(
        title: en ? 'Score' : 'Note',
        value: _label(_scores, _minScore),
        active: _minScore != null,
        options: _scores,
        selected: (v) => v == _minScore,
        onPick: (v) => _change(() => _minScore = v),
      ),
      _Dropdown<(int?, int?)>(
        title: en ? 'Published' : 'Publication',
        value: _label(_years, _year),
        active: _year != null,
        options: _years,
        selected: (v) => v == _year,
        onPick: (v) => _change(() => _year = v),
      ),
      _Dropdown<String>(
        title: en ? 'Origin' : 'Origine',
        value: _label(_countries, _country),
        active: _country != null,
        options: _countries,
        selected: (v) => v == _country,
        onPick: (v) => _change(() => _country = v),
      ),
      _Dropdown<String>(
        title: 'Format',
        value: _label(_formats, _format),
        active: _format != null,
        options: _formats,
        selected: (v) => v == _format,
        onPick: (v) => _change(() => _format = v),
      ),
      if (_filtered)
        Pressable(
          onTap: _clearFilters,
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            alignment: Alignment.center,
            child: Container(
              padding: const EdgeInsets.only(bottom: 2),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: inkRed, width: 2))),
              child: Text(context.t('search.reset'), style: Txt.label(context).copyWith(fontSize: 14)),
            ),
          ),
        ),
    ]);
  }

  List<Widget> _results(BuildContext context, EdgeInsets pad) {
    final en = context.isEn;
    if (_items.isEmpty) {
      if (_error != null) {
        return [
          SliverToBoxAdapter(
            child: EmptyState(
              icon: Icons.wifi_off_rounded,
              title: en ? 'AniList didn’t answer.' : 'AniList ne répond pas.',
              action: AppButton(label: context.t('detail.retry'), tone: ButtonTone.quiet, onTap: _reset),
            ),
          ),
        ];
      }
      if (!_loading && !_hasNext) {
        return [SliverToBoxAdapter(child: EmptyState(icon: Icons.search_off_rounded, title: context.t('search.empty')))];
      }
      // First page on its way: placeholders in the grid's shape.
      return [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(pad.left, 0, pad.right, pad.bottom),
          sliver: SliverGrid.builder(
            gridDelegate: _grid,
            itemCount: 12,
            itemBuilder: (_, _) => const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Skeleton(radius: 0)),
              SizedBox(height: 8),
              Skeleton(height: 12, width: 110),
            ]),
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: EdgeInsets.fromLTRB(pad.left, 0, pad.right, 0),
        sliver: SliverGrid.builder(
          gridDelegate: _grid,
          itemCount: _items.length,
          itemBuilder: (context, i) {
            // Only the first screenful plays its entrance; later results simply appear.
            final fresh = DateTime.now().difference(_shownAt) < const Duration(milliseconds: 900);
            return _ResultCard(media: _items[i], delay: fresh ? Duration(milliseconds: 30 * min(i, 18)) : null);
          },
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(pad.left, 22, pad.right, pad.bottom + 10),
          child: Center(
            child: _error != null
                ? AppButton(label: context.t('detail.retry'), tone: ButtonTone.quiet, onTap: _load)
                : _hasNext
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: inkRed))
                    : Text(en ? 'That’s everything.' : 'C’est tout pour cette recherche.', style: Txt.caption(context)),
          ),
        ),
      ),
    ];
  }

  static const _grid = SliverGridDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: 170,
    mainAxisSpacing: 24,
    crossAxisSpacing: 20,
    childAspectRatio: 0.52,
  );
}

/// Square segmented button (sort order).
class _Segment extends StatelessWidget {
  const _Segment({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(-2, 0),
      child: Pressable(
        onTap: onTap,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: active ? inkBlack : Colors.transparent, border: Border.all(color: inkBlack, width: 2)),
          child: Text(label, style: Txt.label(context).copyWith(fontSize: 13, color: active ? inkPaper : inkBlack)),
        ),
      ),
    );
  }
}

MenuStyle _menuStyle() => const MenuStyle(
      backgroundColor: WidgetStatePropertyAll(Color(0xFFFBF8F1)),
      surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
      elevation: WidgetStatePropertyAll(0),
      shape: WidgetStatePropertyAll(RoundedRectangleBorder(side: BorderSide(color: inkBlack, width: 2))),
      padding: WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 6)),
    );

/// The face of a filter: small caps title over the current value, with a chevron.
class _FilterFace extends StatelessWidget {
  const _FilterFace({required this.title, required this.value, required this.active, required this.onTap});
  final String title, value;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = active ? inkPaper : inkBlack;
    return Pressable(
      onTap: onTap,
      child: Container(
        height: 52,
        constraints: const BoxConstraints(minWidth: 120),
        padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
        decoration: BoxDecoration(color: active ? inkBlack : const Color(0xFFFBF8F1), border: Border.all(color: inkBlack, width: 2)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(title.toUpperCase(), style: Txt.tag(context).copyWith(fontSize: 10, letterSpacing: 1.2, color: active ? const Color(0xFFCFC6B5) : context.pal.text3)),
            const SizedBox(height: 2),
            Text(value, style: Txt.label(context).copyWith(fontSize: 14, color: fg)),
          ]),
          const SizedBox(width: 6),
          Icon(Icons.expand_more_rounded, size: 20, color: fg),
        ]),
      ),
    );
  }
}

class _Dropdown<T> extends StatelessWidget {
  const _Dropdown({required this.title, required this.value, required this.active, required this.options, required this.selected, required this.onPick});
  final String title, value;
  final bool active;
  final List<_Opt<T>> options;
  final bool Function(T?) selected;
  final ValueChanged<T?> onPick;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      style: _menuStyle(),
      alignmentOffset: const Offset(0, 6),
      menuChildren: [
        for (final (v, fr, en) in options)
          MenuItemButton(
            onPressed: () => onPick(v),
            leadingIcon: Icon(selected(v) ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded, size: 18, color: selected(v) ? inkRed : inkBlack),
            child: Text(context.isEn ? en : fr, style: Txt.label(context).copyWith(fontSize: 14)),
          ),
      ],
      builder: (context, menu, _) => _FilterFace(title: title, value: value, active: active, onTap: () => menu.isOpen ? menu.close() : menu.open()),
    );
  }
}

/// Genres: several can be ticked (a manga must have all of them); the list stays open.
class _GenreDropdown extends StatelessWidget {
  const _GenreDropdown({required this.title, required this.value, required this.selected, required this.onToggle, required this.onClear});
  final String title, value;
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      style: _menuStyle(),
      alignmentOffset: const Offset(0, 6),
      menuChildren: [
        for (final (v, fr, en) in _genres)
          MenuItemButton(
            closeOnActivate: false,
            onPressed: () => onToggle(v),
            leadingIcon: _Check(on: selected.contains(v)),
            child: Text(context.isEn ? en : fr, style: Txt.label(context).copyWith(fontSize: 14)),
          ),
        if (selected.isNotEmpty)
          MenuItemButton(
            onPressed: onClear,
            leadingIcon: const Icon(Icons.close_rounded, size: 18, color: inkRed),
            child: Text(context.isEn ? 'Clear genres' : 'Effacer les catégories', style: Txt.label(context).copyWith(fontSize: 14, color: inkRed)),
          ),
      ],
      builder: (context, menu, _) => _FilterFace(title: title, value: value, active: selected.isNotEmpty, onTap: () => menu.isOpen ? menu.close() : menu.open()),
    );
  }
}

/// Square ink checkbox; rebuilt by the menu when the selection changes.
class _Check extends StatelessWidget {
  const _Check({required this.on});
  final bool on;

  @override
  Widget build(BuildContext context) => Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(color: on ? inkBlack : Colors.transparent, border: Border.all(color: inkBlack, width: 2)),
        child: on ? const Icon(Icons.check_rounded, size: 13, color: inkPaper) : null,
      );
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.media, this.delay});
  final AniMedia media;
  final Duration? delay;

  @override
  Widget build(BuildContext context) {
    final m = media;
    final score = m.meanScore != null ? '★ ${(m.meanScore! / 10).toStringAsFixed(1).replaceAll('.', ',')}' : null;
    final sub = [?score, if (m.year != null) '${m.year}', if (m.genres.isNotEmpty) m.genres.first].join(' · ');
    final tag = 'search-${m.id}';
    final inList = Services.i.session.entryFor(m.id);
    return Pressable(
      onTap: () => Navigator.of(context).push(SoftRoute(MangaPage.anilist(m, heroTag: tag))),
      child: OneShot(
        delay: delay ?? Duration.zero,
        duration: const Duration(milliseconds: 380),
        start: delay == null ? 1 : 0,
        builder: (context, t, child) => Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(0, 16 * (1 - Motion.easeOut.transform(t))), child: child),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Stack(clipBehavior: Clip.none, children: [
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(boxShadow: [BoxShadow(color: inkBlack, offset: Offset(4, 4))]),
                  foregroundDecoration: BoxDecoration(border: Border.all(color: inkBlack, width: 2)),
                  child: CoverImage(url: m.cover, radius: 0, title: m.title, heroTag: tag),
                ),
              ),
              if (inList?.status == 'COMPLETED' || inList?.status == 'REPEATING')
                const Positioned(right: -8, bottom: -6, child: HankoStamp(size: 40, animate: false))
              else if (inList != null)
                Positioned(
                  left: -4,
                  top: 12,
                  child: Transform.rotate(
                    angle: -4 * pi / 180,
                    child: InkStretchTag(
                      context.isEn ? 'ON MY LIST' : 'DANS MA LISTE',
                      delay: (delay ?? Duration.zero) + const Duration(milliseconds: 320),
                      animate: delay != null,
                    ),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 10),
          // Always two lines' room, so a long title never shrinks the cover above it.
          SizedBox(
            height: 34,
            child: Text(m.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Txt.label(context).copyWith(fontSize: 14, height: 1.2)),
          ),
          const SizedBox(height: 3),
          Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: Txt.caption(context).copyWith(fontSize: 12)),
        ]),
      ),
    );
  }
}
