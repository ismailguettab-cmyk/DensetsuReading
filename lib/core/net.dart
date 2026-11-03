import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

const _browserUa =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130 Safari/537.36';
const _appUa = 'DensetsuReading/0.1';

class HttpError implements Exception {
  HttpError(this.status, this.url);
  final int status;
  final String url;

  @override
  String toString() => 'HTTP $status';
}

/// Every network call to a manga site goes through here. In the web preview the
/// browser blocks cross-origin calls and custom Referer headers, so requests are
/// routed through the local relay (`tool/dev_server.mjs`); on tablets they go direct.
class Net {
  Net._();

  static final _client = http.Client();

  static Uri resolve(String url, [Map<String, String> headers = const {}]) {
    if (!kIsWeb) return Uri.parse(url);
    return Uri(path: '/proxy', queryParameters: {
      'url': url,
      if (headers['Referer'] != null) 'referer': headers['Referer']!,
    });
  }

  static Map<String, String> nativeHeaders(String url, Map<String, String> headers) {
    if (kIsWeb) return const {};
    final host = Uri.parse(url).host;
    return {'User-Agent': host.endsWith('mangadex.org') ? _appUa : _browserUa, ...headers};
  }

  static Future<http.Response> get(String url, {Map<String, String> headers = const {}}) async {
    final res = await _client.get(resolve(url, headers), headers: nativeHeaders(url, headers));
    if (res.statusCode >= 400) throw HttpError(res.statusCode, url);
    return res;
  }

  static Future<String> getText(String url, {Map<String, String> headers = const {}}) async =>
      utf8.decode((await get(url, headers: headers)).bodyBytes, allowMalformed: true);

  static Future<dynamic> getJson(String url, {Map<String, String> headers = const {}}) async =>
      jsonDecode(await getText(url, headers: headers));

  static Future<Uint8List> getBytes(String url, {Map<String, String> headers = const {}}) async =>
      (await get(url, headers: headers)).bodyBytes;

  /// URL to hand to an image widget.
  static String image(String url, [Map<String, String> headers = const {}]) =>
      resolve(url, headers).toString();
}
