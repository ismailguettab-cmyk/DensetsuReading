import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'anilist.dart';

/// Who is signed in, their AniList profile and manga list.
/// Two modes: OAuth token (read + write progress) or a public username (read-only).
class Session extends ChangeNotifier {
  Session(this._prefs) {
    token = _prefs.getString(_tokenKey);
    username = _prefs.getString(_userKey);
  }

  static const _tokenKey = 'anilist.token';
  static const _userKey = 'anilist.username';
  final SharedPreferences _prefs;

  String? token;
  String? username;
  AniUser? user;
  List<AniEntry> entries = const [];
  bool loading = false;
  Object? error;

  bool get hasCredentials => token != null || username != null;
  bool get canWrite => token != null;
  AniList get api => AniList(token);

  Set<int> get listIds => {for (final e in entries) e.media.id};

  AniEntry? entryFor(int mediaId) {
    for (final e in entries) {
      if (e.media.id == mediaId) return e;
    }
    return null;
  }

  List<AniEntry> withStatus(Set<String> statuses) => entries.where((e) => statuses.contains(e.status)).toList();

  Future<void> signInWithToken(String value) async {
    token = value.trim();
    username = null;
    await _prefs.setString(_tokenKey, token!);
    await _prefs.remove(_userKey);
    await refresh();
  }

  /// Returns false when the user can't be found (or their list is private).
  Future<bool> signInWithUsername(String name) async {
    final found = await AniList().userByName(name.trim());
    if (found == null) return false;
    token = null;
    username = found.name;
    await _prefs.setString(_userKey, found.name);
    await _prefs.remove(_tokenKey);
    user = found;
    notifyListeners();
    await refresh();
    return true;
  }

  Future<void> refresh() async {
    if (!hasCredentials) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final api = this.api;
      final u = token != null ? await api.viewer() : await api.userByName(username!);
      if (u == null) throw AniListError('user not found', 404);
      user = u;
      entries = await api.mangaList(u.id);
    } catch (e) {
      error = e;
      if (e is AniListError && (e.status == 401 || e.status == 400) && token != null) {
        await signOut();
      }
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    token = null;
    username = null;
    user = null;
    entries = const [];
    await _prefs.remove(_tokenKey);
    await _prefs.remove(_userKey);
    notifyListeners();
  }

  /// Pushes progress to AniList (token mode only). Never moves progress backwards.
  Future<void> recordProgress(AniMedia media, int chapter) async {
    if (!canWrite || chapter <= 0) return;
    final current = entryFor(media.id);
    if (current != null && current.progress >= chapter) return;
    final finished = media.chapters != null && chapter >= media.chapters!;
    final status = finished ? 'COMPLETED' : 'CURRENT';
    try {
      await api.saveEntry(media.id, status: status, progress: chapter);
      final entry = AniEntry(
        media: current?.media ?? media,
        status: status,
        score: current?.score ?? 0,
        progress: chapter,
        updated: DateTime.now(),
      );
      entries = [entry, ...entries.where((e) => e.media.id != media.id)];
      notifyListeners();
    } catch (_) {
      // Progress sync is best-effort; reading must never fail because of it.
    }
  }

  Future<bool> addToPlan(AniMedia media) async {
    if (!canWrite) return false;
    await api.saveEntry(media.id, status: 'PLANNING');
    entries = [
      AniEntry(media: media, status: 'PLANNING', score: 0, progress: 0, updated: DateTime.now()),
      ...entries.where((e) => e.media.id != media.id),
    ];
    notifyListeners();
    return true;
  }
}
