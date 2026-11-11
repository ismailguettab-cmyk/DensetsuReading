import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'net.dart';

/// "Upscale" in the reader: a low-resolution page is enlarged with bicubic resampling and
/// its edges sharpened, so it stays crisp on a big screen. Runs on the device, free, in a
/// background isolate; only on demand. Pages already sharp enough are left untouched.
class Upscaler {
  Upscaler._();

  static final _cache = <String, Future<Uint8List?>>{};

  /// Below this width a page looks soft on a tablet; it's doubled (up to [_maxWidth]).
  static const _sharpWidth = 1400;
  static const _maxWidth = 2400;

  /// The enhanced page (JPEG), or null when it's already sharp or couldn't be processed.
  static Future<Uint8List?> page(String url, Map<String, String> headers) {
    if (_cache.length > 16) _cache.remove(_cache.keys.first); // keep memory in check
    return _cache[url] ??= Net.getBytes(url, headers: headers).then(_inBackground).catchError((Object _) => null);
  }

  static Future<Uint8List?> _inBackground(Uint8List bytes) => compute(_enhance, bytes);
}

Uint8List? _enhance(Uint8List bytes) {
  final src = img.decodeImage(bytes);
  if (src == null || src.width >= Upscaler._sharpWidth) return null;
  final width = min(src.width * 2, Upscaler._maxWidth);
  final big = img.copyResize(src, width: width, interpolation: img.Interpolation.cubic);
  // Unsharp kernel blended at half strength: restores the edges the enlargement softened
  // without the halos of a full sharpen.
  final sharp = img.convolution(big, filter: const [0, -1, 0, -1, 5, -1, 0, -1, 0], amount: 0.5);
  return Uint8List.fromList(img.encodeJpg(sharp, quality: 93));
}
