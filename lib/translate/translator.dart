import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:http/http.dart' as http;

import '../core/net.dart';
import '../core/settings.dart';
import '../sources/source.dart';

/// One lettered area of a page, with its French replacement.
/// Boxes are fractions (0–1) of the image width/height.
class Bubble {
  Bubble({
    required this.kind,
    required this.textBox,
    required this.area,
    required this.original,
    required this.translation,
    required this.uppercase,
    required this.lines,
    required this.textColor,
    required this.background,
  });

  final String kind;
  final Rect textBox;
  final Rect area; // safe interior of the balloon, always contains textBox
  final String original, translation;
  final bool uppercase;
  final int lines;
  final Color textColor, background;

  bool get replace => kind != 'sfx' && translation.trim().isNotEmpty;
}

class TranslationError implements Exception {
  TranslationError(this.message);
  final String message;
  @override
  String toString() => message;
}

const _model = 'claude-opus-5-5';

const _system = '''
You translate the English lettering of manga and comic pages into natural French for a reader app. The app paints the balloon interior with its background colour and letters your French text inside it, so positions must be precise.

For the page image, find every piece of English lettering in speech balloons, thought balloons, narration boxes and captions (and signs lettered on a plain background). For each one return:
- text_box: tight box around the existing lettering, [x0, y0, x1, y1] in thousandths of the image width and height (0–1000).
- balloon_box: the largest axis-aligned rectangle inside the balloon or box interior that can be painted over without touching the outline or the art. It must contain text_box.
- lines: how many lines the original lettering uses.
- uppercase: whether the original is lettered in capitals.
- text_color and background_color: hex colours of the lettering and of the balloon interior (usually #000000 on #FFFFFF).
- kind: speech, thought, narration, sign or sfx (sound effects drawn into the art).
- original and translation.

Translation:
- Write fluent French the way a professional French manga edition would: same tone, register (tu or vous from the relationship), slang, emotion and punctuation (… ! ?).
- Japanese context stays Japanese: names and family names as written; honorifics exactly (-san, -kun, -chan, -sama, -dono, -senpai, -sensei, nii-san, nee-chan…); named techniques, attacks, spells, jutsu, stances, transformations and other special terms as they appear in romaji; Japanese words the English edition left untranslated.
- Keep each translation close to the original length so it fits the same balloon; prefer the shorter French phrasing when two are equally natural.
- Never add notes, brackets or explanations.
Return an empty list when the page has no English lettering.
''';

const _schema = {
  'type': 'object',
  'additionalProperties': false,
  'required': ['bubbles'],
  'properties': {
    'bubbles': {
      'type': 'array',
      'items': {
        'type': 'object',
        'additionalProperties': false,
        'required': [
          'kind', 'text_box', 'balloon_box', 'original', 'translation', 'uppercase', 'lines', 'text_color', 'background_color',
        ],
        'properties': {
          'kind': {
            'type': 'string',
            'enum': ['speech', 'thought', 'narration', 'sign', 'sfx'],
          },
          'text_box': {'type': 'array', 'items': {'type': 'integer'}},
          'balloon_box': {'type': 'array', 'items': {'type': 'integer'}},
          'original': {'type': 'string'},
          'translation': {'type': 'string'},
          'uppercase': {'type': 'boolean'},
          'lines': {'type': 'integer'},
          'text_color': {'type': 'string'},
          'background_color': {'type': 'string'},
        },
      },
    },
  },
};

/// Claude-powered translation of pages and synopses. Results are cached per page URL.
class Translator {
  Translator(this._settings);

  final Settings _settings;
  final _pages = <String, Future<List<Bubble>>>{};
  final _texts = <String, Future<String>>{};

  bool get ready => _settings.claudeKey.trim().isNotEmpty;

  Future<List<Bubble>> page(PageImage image) {
    final cached = _pages[image.url];
    if (cached != null) return cached;
    final future = _translatePage(image);
    _pages[image.url] = future;
    future.catchError((Object _) {
      _pages.remove(image.url);
      return <Bubble>[];
    });
    return future;
  }

  Future<String> text(String english) {
    return _texts[english] ??= _call(
      system: 'Translate the manga synopsis you receive into natural French, as printed on the back of a French edition. '
          'Keep Japanese names, honorifics and named techniques as written. Reply with the translation only.',
      content: [
        {'type': 'text', 'text': english},
      ],
    ).then((r) => _firstText(r).trim());
  }

  Future<List<Bubble>> _translatePage(PageImage image) async {
    final bytes = await Net.getBytes(image.url, headers: image.headers);
    final response = await _call(
      system: _system,
      schema: _schema,
      content: [
        {
          'type': 'image',
          'source': {'type': 'base64', 'media_type': _mediaType(bytes), 'data': base64Encode(bytes)},
        },
        {'type': 'text', 'text': 'Translate every piece of English lettering on this page into French.'},
      ],
    );
    final json = jsonDecode(_firstText(response)) as Map<String, dynamic>;
    return [
      for (final b in (json['bubbles'] as List? ?? const []))
        if (_box(b['text_box']) != null)
          Bubble(
            kind: b['kind'] as String,
            textBox: _box(b['text_box'])!,
            area: _box(b['balloon_box'])?.expandToInclude(_box(b['text_box'])!) ?? _box(b['text_box'])!,
            original: b['original'] as String,
            translation: b['translation'] as String,
            uppercase: b['uppercase'] as bool? ?? false,
            lines: ((b['lines'] as int?) ?? 1).clamp(1, 12),
            textColor: _color(b['text_color'] as String?, const Color(0xFF000000)),
            background: _color(b['background_color'] as String?, const Color(0xFFFFFFFF)),
          ),
    ];
  }

  Future<Map<String, dynamic>> _call({
    required String system,
    required List<Map<String, dynamic>> content,
    Map<String, dynamic>? schema,
  }) async {
    if (!ready) throw TranslationError('missing-key');
    final res = await http.post(
      Uri.parse('https://api.anthropic.com/v1/messages'),
      headers: {
        'content-type': 'application/json',
        'x-api-key': _settings.claudeKey.trim(),
        'anthropic-version': '2026-10-21',
        'anthropic-beta': 'server-side-fallback-2026-07-01',
        // The web preview calls the API straight from the browser.
        'anthropic-dangerous-direct-browser-access': 'true',
      },
      body: jsonEncode({
        'model': _model,
        'max_tokens': 16000,
        'fallbacks': 'default',
        'output_config': {
          'effort': 'medium',
          if (schema != null) 'format': {'type': 'json_schema', 'schema': schema},
        },
        'system': system,
        'messages': [
          {'role': 'user', 'content': content},
        ],
      }),
    );
    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    if (res.statusCode >= 400) {
      throw TranslationError((body['error']?['message'] as String?) ?? 'HTTP ${res.statusCode}');
    }
    if (body['stop_reason'] == 'refusal') throw TranslationError('refusal');
    return body;
  }

  static String _firstText(Map<String, dynamic> response) {
    for (final block in (response['content'] as List? ?? const [])) {
      if (block['type'] == 'text') return block['text'] as String;
    }
    throw TranslationError('empty response');
  }

  static Rect? _box(Object? raw) {
    if (raw is! List || raw.length != 4) return null;
    final v = raw.map((e) => ((e as num).toDouble() / 1000).clamp(0.0, 1.0)).toList();
    final r = Rect.fromLTRB(v[0], v[1], v[2], v[3]);
    return (r.width <= 0 || r.height <= 0) ? null : r;
  }

  static Color _color(String? hex, Color fallback) {
    final h = hex?.replaceAll('#', '');
    if (h == null || h.length != 6) return fallback;
    final v = int.tryParse(h, radix: 16);
    return v == null ? fallback : Color(0xFF000000 | v);
  }

  static String _mediaType(Uint8List b) {
    if (b.length > 3 && b[0] == 0x89 && b[1] == 0x50) return 'image/png';
    if (b.length > 12 && b[0] == 0x52 && b[1] == 0x49 && b[8] == 0x57 && b[9] == 0x45) return 'image/webp';
    if (b.length > 3 && b[0] == 0x47 && b[1] == 0x49) return 'image/gif';
    return 'image/jpeg';
  }
}
