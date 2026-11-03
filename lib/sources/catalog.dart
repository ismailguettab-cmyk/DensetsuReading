import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mangadex.dart';
import 'mangathemesia.dart';
import 'mangapill.dart';
import 'scanvf.dart';
import 'source.dart';

/// Every source the app knows how to read.
final List<MangaSource> allSources = [
  MangaDex('fr', 'Français', 96),
  MangaDex('en', 'English', 99),
  MangaDex('es-la', 'Español (LatAm)', 78),
  MangaDex('pt-br', 'Português (BR)', 76),
  MangaDex('it', 'Italiano', 62),
  MangaDex('de', 'Deutsch', 55),
  MangaPill(),
  ScanVF(),
  MangaThemesia(
    id: 'sushiscan',
    name: 'Sushi-Scan',
    lang: 'fr',
    baseUrl: 'https://sushiscan.net',
    catalogPath: '/catalogue',
    popularity: 90,
    genres: sushiScanGenres,
  ),
];

MangaSource? sourceById(String id) {
  for (final s in allSources) {
    if (s.id == id) return s;
  }
  return null;
}

const languageNames = {
  'fr': ('Français', 'French'),
  'en': ('Anglais', 'English'),
  'es-la': ('Espagnol', 'Spanish'),
  'pt-br': ('Portugais', 'Portuguese'),
  'it': ('Italien', 'Italian'),
  'de': ('Allemand', 'German'),
};

String languageName(String code, bool english) {
  final n = languageNames[code];
  return n == null ? code.toUpperCase() : (english ? n.$2 : n.$1);
}

/// Sources the user installed, in install order.
class SourceStore extends ChangeNotifier {
  SourceStore(this._prefs) {
    final raw = _prefs.getString(_key);
    if (raw != null) _ids = (jsonDecode(raw) as List).cast<String>();
  }

  static const _key = 'sources.installed';
  final SharedPreferences _prefs;
  List<String> _ids = [];

  List<MangaSource> get installed => [for (final id in _ids) ?sourceById(id)];
  bool isInstalled(MangaSource s) => _ids.contains(s.id);

  void install(MangaSource s) {
    if (isInstalled(s)) return;
    _ids = [..._ids, s.id];
    _save();
  }

  void remove(MangaSource s) {
    _ids = _ids.where((id) => id != s.id).toList();
    _save();
  }

  void _save() {
    _prefs.setString(_key, jsonEncode(_ids));
    notifyListeners();
  }
}
