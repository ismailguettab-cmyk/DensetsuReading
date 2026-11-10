import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ReadDirection { rtl, ltr, vertical }

enum PageLayout { single, double, auto }

/// How a page (or a two-page spread) occupies the screen. Never stretches.
/// `fill` covers the whole screen edge to edge and lets you scroll what overflows.
enum PageFit { fit, fill, width }

enum ReaderBackground { black, gray, white }

T _enum<T extends Enum>(List<T> values, Object? name, T fallback) =>
    values.firstWhere((v) => v.name == name, orElse: () => fallback);

class Settings extends ChangeNotifier {
  Settings(this._prefs) {
    final raw = _prefs.getString(_key);
    if (raw != null) _read(jsonDecode(raw) as Map<String, dynamic>);
  }

  static const _key = 'settings.v1';
  final SharedPreferences _prefs;

  ThemeMode themeMode = ThemeMode.light;
  String language = 'fr';

  ReadDirection direction = ReadDirection.rtl;
  PageLayout layout = PageLayout.auto;
  PageFit singleFit = PageFit.fit;
  PageFit doubleFit = PageFit.fill;
  bool invertDouble = false;
  bool shiftDouble = false;
  bool tapZones = true;
  bool invertTaps = false;
  ReaderBackground background = ReaderBackground.black;
  bool showPageNumber = true;
  bool pageAnimation = true;

  String geminiKey = '';

  /// Read-only GitHub token, only needed for in-app updates while the repository is private.
  String githubToken = '';
  String anilistClientId = const String.fromEnvironment('ANILIST_CLIENT_ID');

  void update(void Function(Settings s) change) {
    change(this);
    _prefs.setString(_key, jsonEncode(_write()));
    notifyListeners();
  }

  Map<String, dynamic> _write() => {
        'themeMode': themeMode.name,
        'language': language,
        'direction': direction.name,
        'layout': layout.name,
        'singleFit': singleFit.name,
        'doubleFit': doubleFit.name,
        'invertDouble': invertDouble,
        'shiftDouble': shiftDouble,
        'tapZones': tapZones,
        'invertTaps': invertTaps,
        'background': background.name,
        'showPageNumber': showPageNumber,
        'pageAnimation': pageAnimation,
        'geminiKey': geminiKey,
        'githubToken': githubToken,
        'anilistClientId': anilistClientId,
      };

  void _read(Map<String, dynamic> j) {
    themeMode = _enum(ThemeMode.values, j['themeMode'], themeMode);
    language = j['language'] as String? ?? language;
    direction = _enum(ReadDirection.values, j['direction'], direction);
    layout = _enum(PageLayout.values, j['layout'], layout);
    singleFit = _enum(PageFit.values, j['singleFit'], singleFit);
    doubleFit = _enum(PageFit.values, j['doubleFit'], doubleFit);
    invertDouble = j['invertDouble'] as bool? ?? invertDouble;
    shiftDouble = j['shiftDouble'] as bool? ?? shiftDouble;
    tapZones = j['tapZones'] as bool? ?? tapZones;
    invertTaps = j['invertTaps'] as bool? ?? invertTaps;
    background = _enum(ReaderBackground.values, j['background'], background);
    showPageNumber = j['showPageNumber'] as bool? ?? showPageNumber;
    pageAnimation = j['pageAnimation'] as bool? ?? pageAnimation;
    geminiKey = j['geminiKey'] as String? ?? geminiKey;
    githubToken = j['githubToken'] as String? ?? githubToken;
    final id = j['anilistClientId'] as String?;
    if (id != null && id.isNotEmpty) anilistClientId = id;
  }
}
