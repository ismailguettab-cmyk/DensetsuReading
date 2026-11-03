import 'package:url_launcher/url_launcher.dart';

/// Access token handed back by AniList's redirect, if the app was opened by one.
String? takeRedirectToken() => null;

Future<void> openAuthorize(String url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
