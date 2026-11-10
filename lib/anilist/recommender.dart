import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/activity.dart';
import 'anilist.dart';
import 'session.dart';

class RecoCategory {
  const RecoCategory(this.key, this.fr, this.en, {this.genre, this.tag});
  final String key, fr, en;
  final String? genre, tag;

  String label(bool english) => english ? en : fr;

  /// GraphQL filter that keeps a manga in this category.
  String get filter => genre != null ? 'genre: "$genre"' : 'tag: "$tag"';

  bool contains(AniMedia m) => genre != null ? m.genres.contains(genre) : m.tags.any((t) => t.name == tag);
}

const recoCategories = [
  RecoCategory('shounen', 'Shōnen', 'Shōnen', tag: 'Shounen'),
  RecoCategory('seinen', 'Seinen', 'Seinen', tag: 'Seinen'),
  RecoCategory('shoujo', 'Shōjo', 'Shōjo', tag: 'Shoujo'),
  RecoCategory('josei', 'Josei', 'Josei', tag: 'Josei'),
  RecoCategory('action', 'Action', 'Action', genre: 'Action'),
  RecoCategory('adventure', 'Aventure', 'Adventure', genre: 'Adventure'),
  RecoCategory('fantasy', 'Fantasy', 'Fantasy', genre: 'Fantasy'),
  RecoCategory('thriller', 'Thriller', 'Thriller', genre: 'Thriller'),
  RecoCategory('mystery', 'Mystère', 'Mystery', genre: 'Mystery'),
  RecoCategory('psychological', 'Psychologique', 'Psychological', genre: 'Psychological'),
  RecoCategory('romance', 'Romance', 'Romance', genre: 'Romance'),
  RecoCategory('comedy', 'Comédie', 'Comedy', genre: 'Comedy'),
  RecoCategory('drama', 'Drame', 'Drama', genre: 'Drama'),
  RecoCategory('horror', 'Horreur', 'Horror', genre: 'Horror'),
  RecoCategory('scifi', 'Science-fiction', 'Sci-fi', genre: 'Sci-Fi'),
  RecoCategory('sol', 'Tranche de vie', 'Slice of life', genre: 'Slice of Life'),
  RecoCategory('sports', 'Sport', 'Sports', genre: 'Sports'),
  RecoCategory('supernatural', 'Surnaturel', 'Supernatural', genre: 'Supernatural'),
];

class RecoRow {
  RecoRow(this.key, this.labelFr, this.labelEn, this.items);
  final String key, labelFr, labelEn;
  final List<AniMedia> items;

  Map<String, dynamic> toJson() => {'key': key, 'fr': labelFr, 'en': labelEn, 'items': [for (final m in items) m.toJson()]};

  static RecoRow fromJson(Map<String, dynamic> j) => RecoRow(
        j['key'] as String,
        j['fr'] as String,
        j['en'] as String,
        [for (final m in j['items'] as List) AniMedia.fromJson(m as Map<String, dynamic>)],
      );
}

/// Taste profile built from the AniList list and in-app activity.
/// Weights are signed: dropped titles push their genres and tags down.
class TasteProfile {
  final genres = <String, double>{};
  final tags = <String, double>{};
  final searchTerms = <String>{};

  bool get isEmpty => genres.isEmpty && tags.isEmpty;

  double genreAffinity(AniMedia m) {
    if (isEmpty) return 0;
    final maxG = genres.values.fold<double>(0.001, (a, b) => max(a, b.abs()));
    final maxT = tags.isEmpty ? 1.0 : tags.values.fold<double>(0.001, (a, b) => max(a, b.abs()));
    var g = 0.0;
    for (final name in m.genres) {
      g += (genres[name] ?? 0) / maxG;
    }
    var t = 0.0;
    for (final tag in m.tags) {
      t += (tags[tag.name] ?? 0) / maxT * (tag.rank / 100);
    }
    final gNorm = m.genres.isEmpty ? 0 : g / sqrt(m.genres.length);
    final tNorm = m.tags.isEmpty ? 0 : t / sqrt(min(m.tags.length, 12));
    // Tags say more about taste than broad genres.
    return (0.45 * gNorm + 0.55 * tNorm).clamp(-1.0, 1.5);
  }

  double searchAffinity(AniMedia m) {
    if (searchTerms.isEmpty) return 0;
    final hay = '${m.searchTitles.join(' ')} ${m.genres.join(' ')} ${m.tags.map((t) => t.name).join(' ')}'.toLowerCase();
    var hits = 0;
    for (final term in searchTerms) {
      if (hay.contains(term)) hits++;
    }
    return min(1, hits / 2);
  }

  /// Strongest liked tags, best first (category tags like "Shounen" left out).
  List<String> topTags(int n, {Set<String> skip = const {}}) {
    final list = tags.entries.where((e) => e.value > 0 && !skip.contains(e.key)).toList()..sort((a, b) => b.value.compareTo(a.value));
    return list.take(n).map((e) => e.key).toList();
  }

  List<String> topGenres(int n, {Set<String> skip = const {}}) {
    final list = genres.entries.where((e) => e.value > 0 && !skip.contains(e.key)).toList()..sort((a, b) => b.value.compareTo(a.value));
    return list.take(n).map((e) => e.key).toList();
  }
}

/// Recommendations driven by taste, not by scores or popularity.
///
/// Each category gets two candidate pools from the whole AniList catalogue: one aimed at
/// the user's favourite themes inside the category, one that explores it at random (random
/// sort order and random page anywhere in the catalogue). Candidates are ranked by how well
/// they match the user's taste *for that category*, plus what AniList readers recommend
/// after the user's favourites; titles shown in the last draws are pushed back so the
/// same famous series don't come round again and again.
///
/// The last draw is cached on disk and shown at once on the next launch while a fresh one
/// is computed. A draw is kept for 5 minutes, then each visit draws again.
class Recommender extends ChangeNotifier {
  Recommender(this._prefs, this._session, this._activity) {
    final shown = _prefs.getString(_historyKey);
    if (shown != null) {
      _history = (jsonDecode(shown) as Map<String, dynamic>).map((k, v) => MapEntry(int.parse(k), v as int));
    }
    _drawCount = _prefs.getInt(_drawCountKey) ?? 0;
    final pages = _prefs.getString(_pagesKey);
    if (pages != null) _lastPages = (jsonDecode(pages) as Map<String, dynamic>).map((k, v) => MapEntry(k, v as int));
    _loadCache();
  }

  static const keepFor = Duration(minutes: 5);
  static const perRow = 24; // 4 spreads of 6 in the category book
  static const _cacheKey = 'reco.cache';
  static const _historyKey = 'reco.history';
  static const _drawCountKey = 'reco.draws';
  static const _pagesKey = 'reco.pages';
  final SharedPreferences _prefs;
  final Session _session;
  final Activity _activity;
  final _rng = Random();

  List<RecoRow> rows = const [];
  DateTime? drawnAt;
  bool loading = false;
  Object? error;

  /// manga id → draw number when it was last shown.
  Map<int, int> _history = {};
  int _drawCount = 0;

  /// Learned page counts per query kind, so random pages can reach the whole catalogue.
  Map<String, int> _lastPages = {};

  bool get isFresh => drawnAt != null && DateTime.now().difference(drawnAt!) < keepFor;
  Duration get remaining => isFresh ? keepFor - DateTime.now().difference(drawnAt!) : Duration.zero;

  void _loadCache() {
    final raw = _prefs.getString(_cacheKey);
    if (raw == null) return;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      rows = [for (final r in j['rows'] as List) RecoRow.fromJson(r as Map<String, dynamic>)];
      drawnAt = DateTime.fromMillisecondsSinceEpoch(j['at'] as int);
    } catch (_) {
      rows = const [];
    }
  }

  void _saveCache() {
    _prefs.setString(_cacheKey, jsonEncode({'at': drawnAt!.millisecondsSinceEpoch, 'rows': [for (final r in rows) r.toJson()]}));
  }

  void _remember(Iterable<AniMedia> shown) {
    _drawCount++;
    for (final m in shown) {
      _history[m.id] = _drawCount;
    }
    // Forget what's older than 12 draws.
    _history.removeWhere((_, n) => _drawCount - n > 12);
    _prefs.setString(_historyKey, jsonEncode(_history.map((k, v) => MapEntry('$k', v))));
    _prefs.setInt(_drawCountKey, _drawCount);
    _prefs.setString(_pagesKey, jsonEncode(_lastPages));
  }

  /// Called whenever the tab becomes visible, and once the AniList list is loaded.
  Future<void> onVisit() async {
    if (loading || isFresh || !_session.hasCredentials) return;
    await draw();
  }

  void invalidate() {
    drawnAt = null;
    notifyListeners();
  }

  Future<void> draw() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final fresh = await _compute();
      if (fresh.isNotEmpty) {
        rows = fresh;
        drawnAt = DateTime.now();
        _remember([for (final r in rows) ...r.items]);
        _saveCache();
      }
    } catch (e) {
      error = e;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// New picks for one category only (the "Reload" button in its book).
  Future<void> redrawRow(String key) async {
    final index = rows.indexWhere((r) => r.key == key);
    if (index < 0) return;
    try {
      final profile = buildProfile();
      final taken = {for (final r in rows) if (r.key != key) ...r.items.map((m) => m.id)};
      // Push the current picks back too, so the reload really shows other titles.
      final current = rows[index].items.map((m) => m.id).toSet();
      final RecoRow fresh;
      if (key == 'forYou') {
        final pools = await _pools(recoCategories.toList()..shuffle(_rng), profile, limit: 4);
        final collab = await _collab();
        final everything = {for (final p in pools.values) for (final m in p) m.id: m, ...collab.media}.values.toList();
        fresh = RecoRow(key, rows[index].labelFr, rows[index].labelEn,
            _pick(everything, profile, profile, collab.scores, {...taken, ...current}, perRow));
      } else {
        final c = recoCategories.firstWhere((c) => c.key == key);
        final pools = await _pools([c], profile);
        final catProfile = buildProfile(category: c);
        fresh = RecoRow(key, c.fr, c.en, _pick(pools[c.key] ?? const [], catProfile, profile, const {}, {...taken, ...current}, perRow));
      }
      if (fresh.items.length < 6) return;
      rows = [...rows]..[index] = fresh;
      _remember(fresh.items);
      _saveCache();
      notifyListeners();
    } catch (e) {
      error = e;
      notifyListeners();
    }
  }

  /// Taste from the AniList list (status, own score, recency) and in-app activity.
  /// With [category], only the titles of that category count: what the user likes in
  /// romance isn't what they like in horror.
  TasteProfile buildProfile({RecoCategory? category}) {
    final p = TasteProfile();
    final now = DateTime.now();
    final scored = _session.entries.where((e) => e.score > 0).map((e) => e.score).toList();
    final mean = scored.isEmpty ? 70.0 : scored.reduce((a, b) => a + b) / scored.length;

    for (final e in _session.entries) {
      if (category != null && !category.contains(e.media)) continue;
      final statusW = switch (e.status) {
        'COMPLETED' => 1.0,
        'REPEATING' => 1.3,
        'CURRENT' => 1.1,
        'PLANNING' => 0.55,
        'PAUSED' => 0.3,
        'DROPPED' => -0.7,
        _ => 0.2,
      };
      // A score above the user's own average counts more, below counts less.
      final scoreW = e.score > 0 ? (1 + (e.score - mean) / 40).clamp(0.2, 1.8) : 1.0;
      final ageDays = now.difference(e.updated).inDays.clamp(0, 3650);
      final recency = 0.4 + 0.6 * pow(0.5, ageDays / 240);
      final w = statusW * scoreW * recency;
      for (final g in e.media.genres) {
        p.genres[g] = (p.genres[g] ?? 0) + w;
      }
      for (final t in e.media.tags) {
        p.tags[t.name] = (p.tags[t.name] ?? 0) + w * t.rank / 100;
      }
    }

    // Manga opened in the app: recent ones weigh more (half-life of 2 weeks).
    for (final v in _activity.views) {
      final w = 0.6 * pow(0.5, now.difference(v.at).inDays / 14);
      for (final g in v.genres) {
        p.genres[g] = (p.genres[g] ?? 0) + w;
      }
    }
    for (final s in _activity.searches.take(15)) {
      for (final word in s.query.toLowerCase().split(RegExp(r'\s+'))) {
        if (word.length >= 4) p.searchTerms.add(word);
      }
    }
    return p;
  }

  static const _demographics = {'Shounen', 'Seinen', 'Shoujo', 'Josei', 'Kids'};
  static const _tasteSorts = ['FAVOURITES_DESC', 'TRENDING_DESC', 'START_DATE_DESC', 'UPDATED_AT_DESC', 'SCORE_DESC', 'POPULARITY_DESC', 'ID_DESC'];
  static const _exploreSorts = ['ID', 'ID_DESC', 'START_DATE', 'START_DATE_DESC', 'UPDATED_AT_DESC', 'FAVOURITES_DESC', 'CHAPTERS_DESC'];

  T _any<T>(List<T> list) => list[_rng.nextInt(list.length)];

  int _page(String key, int fallback) => 1 + _rng.nextInt(max(1, min(_lastPages[key] ?? fallback, 60)));

  /// Two pools per category (taste + exploration), batched into a few requests run in parallel.
  Future<Map<String, List<AniMedia>>> _pools(List<RecoCategory> categories, TasteProfile global, {int? limit}) async {
    final list = limit == null ? categories : categories.take(limit).toList();
    const perRequest = 4;
    const base = 'type: MANGA, format_not: NOVEL, isAdult: false';
    final requests = <Future<Map<String, dynamic>>>[];
    for (var i = 0; i < list.length; i += perRequest) {
      final q = StringBuffer('query {');
      for (final c in list.skip(i).take(perRequest)) {
        final cat = buildProfile(category: c);
        final source = cat.isEmpty ? global : cat;
        // Themes the user likes in this category (or overall), as a loose "any of" filter.
        final tags = source.topTags(4, skip: {..._demographics, ?c.tag}).toList()..shuffle(_rng);
        final genres = source.topGenres(3, skip: {?c.genre}).toList()..shuffle(_rng);
        final useTags = tags.isNotEmpty && (genres.isEmpty || _rng.nextBool());
        final taste = useTags
            ? 'tag_in: ${jsonEncode(tags.take(3).toList())}'
            : genres.isNotEmpty
                ? 'genre_in: ${jsonEncode(genres.take(2).toList())}'
                : '';
        q.write(' t_${c.key}: Page(page: ${_page('t_${c.key}', 4)}, perPage: 25) { pageInfo { lastPage } '
            'media($base, ${c.filter}${taste.isEmpty ? '' : ', $taste'}, popularity_greater: 80, sort: ${_any(_tasteSorts)}) { ...M } }');
        q.write(' e_${c.key}: Page(page: ${_page('e_${c.key}', 12)}, perPage: 25) { pageInfo { lastPage } '
            'media($base, ${c.filter}, popularity_greater: 150, sort: ${_any(_exploreSorts)}) { ...M } }');
      }
      q.write(' } $mediaFragment');
      requests.add(_session.api.query(q.toString()));
    }
    final results = await Future.wait(requests);
    final pools = <String, List<AniMedia>>{};
    for (final data in results) {
      for (final entry in data.entries) {
        final alias = entry.key;
        final page = entry.value as Map<String, dynamic>?;
        final lastPage = page?['pageInfo']?['lastPage'] as int?;
        if (lastPage != null && lastPage > 0) _lastPages[alias] = lastPage;
        final key = alias.substring(2);
        pools.putIfAbsent(key, () => []).addAll(
              ((page?['media'] as List?) ?? const []).map((m) => AniMedia.fromJson(m as Map<String, dynamic>)),
            );
      }
    }
    return pools;
  }

  /// What AniList readers recommend after some of the user's favourites (a random dozen).
  Future<({Map<int, double> scores, Map<int, AniMedia> media})> _collab() async {
    final liked = [..._session.entries.where((e) => const {'COMPLETED', 'CURRENT', 'REPEATING'}.contains(e.status))]
      ..sort((a, b) => b.score.compareTo(a.score));
    final seeds = liked.take(30).map((e) => e.media.id).toList()..shuffle(_rng);
    final scores = <int, double>{};
    final media = <int, AniMedia>{};
    if (seeds.isEmpty) return (scores: scores, media: media);
    final data = await _session.api.query(
      'query { Page(perPage: 10) { media(id_in: ${jsonEncode(seeds.take(10).toList())}) { id recommendations(perPage: 10, sort: RATING_DESC) '
      '{ nodes { rating mediaRecommendation { ...M } } } } } } $mediaFragment',
    );
    for (final m in (data['Page']?['media'] as List? ?? const [])) {
      for (final n in (m['recommendations']?['nodes'] as List? ?? const [])) {
        final rec = n['mediaRecommendation'];
        if (rec == null) continue;
        final item = AniMedia.fromJson(rec as Map<String, dynamic>);
        if (item.isAdult || item.format == 'NOVEL') continue;
        final rating = (n['rating'] as int? ?? 0).clamp(0, 400);
        scores[item.id] = (scores[item.id] ?? 0) + 1 + log(1 + rating) / 4;
        media[item.id] = item;
      }
    }
    final top = scores.values.fold<double>(1, max);
    return (scores: scores.map((k, v) => MapEntry(k, v / top)), media: media);
  }

  /// Weighted draw without replacement: good matches are likely, not guaranteed, so every
  /// draw feels different while staying on taste.
  List<AniMedia> _pick(List<AniMedia> pool, TasteProfile category, TasteProfile global, Map<int, double> collab, Set<int> taken, int n) {
    final onList = _session.listIds;
    final seen = <int>{};
    final candidates = [
      for (final m in pool)
        if (!onList.contains(m.id) && !taken.contains(m.id) && !m.isAdult && seen.add(m.id)) m,
    ];
    double score(AniMedia m) {
      final affinity = category.isEmpty ? global.genreAffinity(m) : 0.65 * category.genreAffinity(m) + 0.35 * global.genreAffinity(m);
      final c = collab[m.id] ?? 0;
      final search = global.searchAffinity(m);
      // Shown in a recent draw: pushed back, less and less as draws go by.
      final last = _history[m.id];
      final repeat = last == null ? 0.0 : 0.55 * pow(0.75, _drawCount - last);
      // Neither score nor popularity is rewarded; only really poor titles are held back.
      final poor = (m.meanScore != null && m.meanScore! < 58) ? 0.2 : 0.0;
      return 0.7 * affinity + 0.22 * c + 0.08 * search - repeat - poor;
    }

    final scored = {for (final m in candidates) m: score(m)};
    final ranked = candidates..sort((a, b) => scored[b]!.compareTo(scored[a]!));
    final shortlist = ranked.take(max((n * 2.2).round(), 30)).toList();
    final picked = <AniMedia>[];
    while (picked.length < n && shortlist.isNotEmpty) {
      final weights = shortlist.map((m) => exp(scored[m]! / 0.14)).toList();
      final total = weights.reduce((a, b) => a + b);
      var r = _rng.nextDouble() * total;
      var index = 0;
      while (index < weights.length - 1 && (r -= weights[index]) > 0) {
        index++;
      }
      picked.add(shortlist.removeAt(index));
    }
    return picked;
  }

  Future<List<RecoRow>> _compute() async {
    final profile = buildProfile();
    final results = await Future.wait([_pools(recoCategories, profile), _collab()]);
    final pools = results[0] as Map<String, List<AniMedia>>;
    final collab = results[1] as ({Map<int, double> scores, Map<int, AniMedia> media});

    final taken = <int>{};
    final rows = <RecoRow>[];
    final everything = {for (final p in pools.values) for (final m in p) m.id: m, ...collab.media}.values.toList();
    final forYou = _pick(everything, profile, profile, collab.scores, taken, perRow);
    taken.addAll(forYou.map((m) => m.id));
    if (forYou.isNotEmpty) rows.add(RecoRow('forYou', 'Taillés pour toi', 'Made for you', forYou));

    // Categories the user reads most come first.
    double categoryWeight(RecoCategory c) => c.genre != null ? (profile.genres[c.genre] ?? 0) : (profile.tags[c.tag] ?? 0) * 1.4;
    final ordered = [...recoCategories]..sort((a, b) => categoryWeight(b).compareTo(categoryWeight(a)));
    for (final c in ordered) {
      // Collaborative picks that belong to the category join its pool.
      final pool = [...?pools[c.key], ...collab.media.values.where(c.contains)];
      final items = _pick(pool, buildProfile(category: c), profile, collab.scores, taken, perRow);
      taken.addAll(items.map((m) => m.id));
      if (items.length >= 6) rows.add(RecoRow(c.key, c.fr, c.en, items));
    }
    return rows;
  }
}
