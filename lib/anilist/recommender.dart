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
}

/// Taste profile built from the AniList list and in-app activity.
/// Weights are signed: dropped titles push their genres and tags down.
class TasteProfile {
  final genres = <String, double>{};
  final tags = <String, double>{};
  final searchTerms = <String>{};

  double genreAffinity(AniMedia m) {
    if (genres.isEmpty) return 0;
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
    return (0.6 * gNorm + 0.4 * tNorm).clamp(-1.0, 1.5);
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
}

/// Draws ~10 manga per category. A draw is kept for 5 minutes so an accidental
/// tab switch doesn't reshuffle it; after that, each visit draws again.
class Recommender extends ChangeNotifier {
  Recommender(this._prefs, this._session, this._activity) {
    final raw = _prefs.getString(_shownKey);
    if (raw != null) _recentlyShown = (jsonDecode(raw) as List).cast<int>().toSet();
  }

  static const keepFor = Duration(minutes: 5);
  static const _shownKey = 'reco.shown';
  final SharedPreferences _prefs;
  final Session _session;
  final Activity _activity;
  final _rng = Random();

  List<RecoRow> rows = const [];
  DateTime? drawnAt;
  bool loading = false;
  Object? error;
  Set<int> _recentlyShown = {};

  bool get isFresh => drawnAt != null && DateTime.now().difference(drawnAt!) < keepFor;
  Duration get remaining => isFresh ? keepFor - DateTime.now().difference(drawnAt!) : Duration.zero;

  /// Called whenever the tab becomes visible.
  Future<void> onVisit() async {
    if (loading || isFresh) return;
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
      rows = await _compute();
      drawnAt = DateTime.now();
      _recentlyShown = {for (final r in rows) ...r.items.map((m) => m.id)};
      _prefs.setString(_shownKey, jsonEncode(_recentlyShown.toList()));
    } catch (e) {
      error = e;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  TasteProfile buildProfile() {
    final p = TasteProfile();
    final now = DateTime.now();
    final scored = _session.entries.where((e) => e.score > 0).map((e) => e.score).toList();
    final mean = scored.isEmpty ? 70.0 : scored.reduce((a, b) => a + b) / scored.length;

    for (final e in _session.entries) {
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

    // In-app searches: recent ones weigh more (half-life of 2 weeks).
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

  Future<List<RecoRow>> _compute() async {
    final api = _session.api;
    final profile = buildProfile();
    final onList = _session.listIds;

    // 1. Candidate pools per category, from a random slice of the most popular.
    final pools = <String, List<AniMedia>>{};
    const perRequest = 6;
    for (var i = 0; i < recoCategories.length; i += perRequest) {
      final group = recoCategories.skip(i).take(perRequest);
      final q = StringBuffer('query {');
      for (final c in group) {
        final page = 1 + _rng.nextInt(3);
        final filter = c.genre != null ? 'genre: "${c.genre}"' : 'tag: "${c.tag}"';
        q.write(' c_${c.key}: Page(page: $page, perPage: 25) { media(type: MANGA, format_not: NOVEL, isAdult: false, '
            'sort: POPULARITY_DESC, $filter) { ...M } }');
      }
      q.write(' } $mediaFragment');
      final data = await api.query(q.toString());
      for (final c in group) {
        pools[c.key] = ((data['c_${c.key}']?['media'] as List?) ?? const [])
            .map((m) => AniMedia.fromJson(m as Map<String, dynamic>))
            .toList();
      }
    }

    // 2. Collaborative signal: what AniList users recommend after the user's favourites.
    final favourites = [..._session.entries.where((e) => const {'COMPLETED', 'CURRENT', 'REPEATING'}.contains(e.status))]
      ..sort((a, b) => b.score.compareTo(a.score));
    final seeds = favourites.take(12).map((e) => e.media.id).toList()..shuffle(_rng);
    final collab = <int, double>{};
    final collabMedia = <int, AniMedia>{};
    if (seeds.isNotEmpty) {
      final data = await api.query(
        'query { Page(perPage: 10) { media(id_in: ${jsonEncode(seeds.take(10).toList())}) { id recommendations(perPage: 8, sort: RATING_DESC) '
        '{ nodes { rating mediaRecommendation { ...M } } } } } } $mediaFragment',
      );
      for (final m in (data['Page']?['media'] as List? ?? const [])) {
        for (final n in (m['recommendations']?['nodes'] as List? ?? const [])) {
          final rec = n['mediaRecommendation'];
          if (rec == null) continue;
          final media = AniMedia.fromJson(rec as Map<String, dynamic>);
          if (media.isAdult || media.format == 'NOVEL') continue;
          final rating = (n['rating'] as int? ?? 0).clamp(0, 400);
          collab[media.id] = (collab[media.id] ?? 0) + 1 + log(1 + rating) / 3;
          collabMedia[media.id] = media;
        }
      }
    }
    final maxCollab = collab.values.fold<double>(1, max);

    double score(AniMedia m) {
      final affinity = profile.genreAffinity(m);
      final c = (collab[m.id] ?? 0) / maxCollab;
      final quality = ((m.meanScore ?? 62) - 50) / 40;
      final pop = log(1 + (m.popularity ?? 0)) / log(250000);
      final search = profile.searchAffinity(m);
      final repeat = _recentlyShown.contains(m.id) ? 0.35 : 0;
      return 0.42 * affinity + 0.22 * c + 0.16 * quality + 0.1 * pop + 0.1 * search - repeat;
    }

    // Weighted draw without replacement: good matches are likely, not guaranteed,
    // so every visit feels different while staying on-taste.
    List<AniMedia> draw(List<AniMedia> pool, Set<int> taken, int n) {
      final candidates = pool.where((m) => !onList.contains(m.id) && !taken.contains(m.id) && !m.isAdult).toList();
      final scored = {for (final m in candidates) m: score(m)};
      final ranked = candidates..sort((a, b) => scored[b]!.compareTo(scored[a]!));
      final shortlist = ranked.take(max(n * 3, 18)).toList();
      final picked = <AniMedia>[];
      while (picked.length < n && shortlist.isNotEmpty) {
        final weights = shortlist.map((m) => exp(scored[m]! / 0.12)).toList();
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

    final taken = <int>{};
    final rows = <RecoRow>[];

    final everything = {
      for (final pool in pools.values) ...{for (final m in pool) m.id: m},
      ...collabMedia,
    }.values.toList();
    final forYou = draw(everything, taken, 10);
    taken.addAll(forYou.map((m) => m.id));
    if (forYou.isNotEmpty) rows.add(RecoRow('forYou', 'Taillés pour toi', 'Made for you', forYou));

    // Categories the user reads most come first.
    double categoryWeight(RecoCategory c) =>
        c.genre != null ? (profile.genres[c.genre] ?? 0) : (profile.tags[c.tag] ?? 0) * 1.4;
    final ordered = [...recoCategories]..sort((a, b) => categoryWeight(b).compareTo(categoryWeight(a)));
    for (final c in ordered) {
      final items = draw(pools[c.key] ?? const [], taken, 10);
      taken.addAll(items.map((m) => m.id));
      if (items.length >= 4) rows.add(RecoRow(c.key, c.fr, c.en, items));
    }
    return rows;
  }
}
