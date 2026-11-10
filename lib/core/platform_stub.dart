import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

import '../anilist/anilist.dart';

/// Access token handed back by AniList's redirect, if the app was opened by one.
String? takeRedirectToken() => null;

/// AniList client for this platform (empty until it's been created on anilist.co).
String get anilistClientId => AniList.appClientId;

/// Opens AniList's sign-in page in a browser tab; AniList sends the user back to
/// `densetsureading://auth#access_token=…`, which closes the tab and returns the token.
Future<String?> authorize(String url) async {
  final result = await FlutterWebAuth2.authenticate(url: url, callbackUrlScheme: AniList.appCallbackScheme);
  final uri = Uri.parse(result);
  final params = Uri.splitQueryString(uri.fragment.isNotEmpty ? uri.fragment : uri.query);
  return params['access_token'];
}
