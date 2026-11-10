import 'package:web/web.dart' as web;

import '../anilist/anilist.dart';

/// AniList redirects back to the site with #access_token=…; read it once and clean the address bar.
String? takeRedirectToken() {
  final hash = web.window.location.hash;
  if (!hash.contains('access_token=')) return null;
  final params = Uri.splitQueryString(hash.substring(1));
  // Keep the page's own path (the site may live in a sub-folder, e.g. on GitHub Pages).
  web.window.history.replaceState(null, '', web.window.location.pathname);
  return params['access_token'];
}

/// AniList client for the website (the local preview on port 5173 uses the same one).
String get anilistClientId => AniList.webClientId;

/// The whole page goes to AniList and comes back with the token (see [takeRedirectToken]).
Future<String?> authorize(String url) async {
  web.window.location.assign(url);
  return null;
}
