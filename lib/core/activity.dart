import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SearchEvent {
  SearchEvent(this.query, this.at);
  final String query;
  final DateTime at;
}

/// A manga opened from a search: its genres feed the recommender.
class ViewEvent {
  ViewEvent(this.title, this.genres, this.at);
  final String title;
  final List<String> genres;
  final DateTime at;
}

/// Last chapter opened in the app for one manga, to resume reading.
class ReadEvent {
  ReadEvent({
    required this.sourceId,
    required this.mangaUrl,
    required this.title,
    required this.cover,
    required this.chapterUrl,
    required this.chapterName,
    required this.page,
    required this.at,
    this.anilistId,
  });

  final String sourceId, mangaUrl, title, chapterUrl, chapterName;
  final String? cover;
  final int page;
  final int? anilistId;
  final DateTime at;

  String get key => '$sourceId|$mangaUrl';

  Map<String, dynamic> toJson() => {
        's': sourceId,
        'm': mangaUrl,
        't': title,
        'c': cover,
        'cu': chapterUrl,
        'cn': chapterName,
        'p': page,
        'a': anilistId,
        'at': at.millisecondsSinceEpoch,
      };

  factory ReadEvent.fromJson(Map<String, dynamic> j) => ReadEvent(
        sourceId: j['s'] as String,
        mangaUrl: j['m'] as String,
        title: j['t'] as String,
        cover: j['c'] as String?,
        chapterUrl: j['cu'] as String,
        chapterName: j['cn'] as String,
        page: j['p'] as int? ?? 0,
        anilistId: j['a'] as int?,
        at: DateTime.fromMillisecondsSinceEpoch(j['at'] as int),
      );
}

/// What the user does inside the app: searches, manga opened, chapters read.
class Activity extends ChangeNotifier {
  Activity(this._prefs) {
    final raw = _prefs.getString(_key);
    if (raw == null) return;
    final j = jsonDecode(raw) as Map<String, dynamic>;
    searches = [
      for (final s in (j['searches'] as List? ?? const []))
        SearchEvent(s['q'] as String, DateTime.fromMillisecondsSinceEpoch(s['at'] as int)),
    ];
    views = [
      for (final v in (j['views'] as List? ?? const []))
        ViewEvent(v['t'] as String, (v['g'] as List).cast<String>(), DateTime.fromMillisecondsSinceEpoch(v['at'] as int)),
    ];
    reads = [for (final r in (j['reads'] as List? ?? const [])) ReadEvent.fromJson(r as Map<String, dynamic>)];
  }

  static const _key = 'activity.v1';
  final SharedPreferences _prefs;

  List<SearchEvent> searches = [];
  List<ViewEvent> views = [];
  List<ReadEvent> reads = [];

  void logSearch(String query) {
    final q = query.trim();
    if (q.length < 2) return;
    searches = [SearchEvent(q, DateTime.now()), ...searches.where((s) => s.query.toLowerCase() != q.toLowerCase())].take(60).toList();
    _save();
  }

  void logView(String title, List<String> genres) {
    if (genres.isEmpty) return;
    views = [ViewEvent(title, genres, DateTime.now()), ...views.where((v) => v.title != title)].take(80).toList();
    _save();
  }

  void logRead(ReadEvent event) {
    reads = [event, ...reads.where((r) => r.key != event.key)].take(100).toList();
    _save();
  }

  ReadEvent? lastRead(String sourceId, String mangaUrl) {
    for (final r in reads) {
      if (r.sourceId == sourceId && r.mangaUrl == mangaUrl) return r;
    }
    return null;
  }

  void clearSearches() {
    searches = [];
    views = [];
    _save();
  }

  void _save() {
    _prefs.setString(
      _key,
      jsonEncode({
        'searches': [for (final s in searches) {'q': s.query, 'at': s.at.millisecondsSinceEpoch}],
        'views': [for (final v in views) {'t': v.title, 'g': v.genres, 'at': v.at.millisecondsSinceEpoch}],
        'reads': [for (final r in reads) r.toJson()],
      }),
    );
    notifyListeners();
  }
}
