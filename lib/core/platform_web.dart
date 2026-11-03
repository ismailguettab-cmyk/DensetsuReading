import 'package:web/web.dart' as web;

/// AniList redirects back to /auth#access_token=…; read it once and clean the address bar.
String? takeRedirectToken() {
  final hash = web.window.location.hash;
  if (!hash.contains('access_token=')) return null;
  final params = Uri.splitQueryString(hash.substring(1));
  web.window.history.replaceState(null, '', '/');
  return params['access_token'];
}

Future<void> openAuthorize(String url) async => web.window.location.assign(url);
