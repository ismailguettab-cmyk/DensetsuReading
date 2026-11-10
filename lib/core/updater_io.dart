import 'dart:convert';
import 'dart:io';

import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import 'update_info.dart';

export 'update_info.dart';

/// In-app updates from GitHub: reads the "apk-latest" release, downloads the APK,
/// then hands it to Android's installer (the user confirms the install).
class AppUpdater {
  static const _repo = 'ismailguettab-cmyk/DensetsuReading';
  static const _tag = 'apk-latest';

  /// Commit of the running build, set by the GitHub workflow (empty in a local build).
  static const _build = String.fromEnvironment('BUILD_SHA');

  static bool get supported => Platform.isAndroid;
  static String get currentBuild => _build;

  static Map<String, String> _headers(String token, {String accept = 'application/vnd.github+json'}) => {
        'Accept': accept,
        'User-Agent': 'DensetsuReading',
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

  static Future<UpdateInfo> check(String token) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final req = await client.getUrl(Uri.parse('https://api.github.com/repos/$_repo/releases/tags/$_tag'));
      _headers(token).forEach(req.headers.set);
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      // A private repository answers 404 to anyone without a token.
      if (res.statusCode == 404 || res.statusCode == 401) throw UpdateError(UpdateErrorKind.notFound);
      if (res.statusCode != 200) throw UpdateError(UpdateErrorKind.network, 'HTTP ${res.statusCode}');
      final j = jsonDecode(body) as Map<String, dynamic>;
      final asset = ((j['assets'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .where((a) => (a['name'] as String? ?? '').endsWith('.apk'))
          .firstOrNull;
      if (asset == null) throw UpdateError(UpdateErrorKind.notFound);
      final commit = RegExp(r'[0-9a-f]{40}').firstMatch(j['body'] as String? ?? '')?.group(0) ?? '';
      return UpdateInfo(
        commit: commit,
        assetUrl: asset['url'] as String,
        size: asset['size'] as int? ?? 0,
        date: DateTime.tryParse(asset['updated_at'] as String? ?? '') ?? DateTime.now(),
        newer: _build.isEmpty || commit.isEmpty || commit != _build,
      );
    } on SocketException catch (e) {
      throw UpdateError(UpdateErrorKind.network, e.message);
    } finally {
      client.close();
    }
  }

  static Future<File> _file() async => File('${(await getTemporaryDirectory()).path}/DensetsuReading-update.apk');

  /// Downloads the APK; emits progress from 0 to 1.
  static Stream<double> download(UpdateInfo info, String token) async* {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
    try {
      // GitHub answers with a redirect to its file storage; the token must not follow it there.
      var req = await client.getUrl(Uri.parse(info.assetUrl));
      req.followRedirects = false;
      _headers(token, accept: 'application/octet-stream').forEach(req.headers.set);
      var res = await req.close();
      if (res.isRedirect) {
        final location = res.headers.value(HttpHeaders.locationHeader);
        await res.drain<void>();
        if (location == null) throw UpdateError(UpdateErrorKind.network, 'redirect');
        req = await client.getUrl(Uri.parse(location));
        req.headers.set('User-Agent', 'DensetsuReading');
        res = await req.close();
      }
      if (res.statusCode != 200) throw UpdateError(UpdateErrorKind.network, 'HTTP ${res.statusCode}');
      final total = res.contentLength > 0 ? res.contentLength : info.size;
      final file = await _file();
      final sink = file.openWrite();
      var received = 0;
      try {
        await for (final chunk in res) {
          sink.add(chunk);
          received += chunk.length;
          if (total > 0) yield (received / total).clamp(0.0, 1.0);
        }
      } finally {
        await sink.close();
      }
      yield 1;
    } on SocketException catch (e) {
      throw UpdateError(UpdateErrorKind.network, e.message);
    } finally {
      client.close();
    }
  }

  /// Opens Android's installer on the downloaded APK. Returns an error message, or null.
  static Future<String?> install() async {
    final file = await _file();
    final result = await OpenFilex.open(file.path, type: 'application/vnd.android.package-archive');
    return result.type == ResultType.done ? null : result.message;
  }
}
