import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;

import '../core/net.dart';
import 'madara.dart';
import 'source.dart';

// English sites with their own engine (one class each).

String? _src(dynamic img) => (img?.attributes['data-src'] ?? img?.attributes['src'] as String?)?.trim();

/// POST through the web relay (or directly on tablets).
Future<String> _post(String url, String body, {String type = 'application/json', Map<String, String> headers = const {}}) async {
  final uri = kIsWeb ? Uri(path: '/proxy', queryParameters: {'url': url}) : Uri.parse(url);
  final res = await http.post(uri, headers: {...Net.nativeHeaders(url, headers), 'Content-Type': type}, body: body);
  if (res.statusCode >= 400) throw HttpError(res.statusCode, url);
  return utf8.decode(res.bodyBytes, allowMalformed: true);
}

/// Toonily — Madara variant: `/webtoons/` catalogue and `/search/{query}` search.
class Toonily extends Madara {
  Toonily() : super(id: 'toonily', name: 'Toonily', lang: 'en', baseUrl: 'https://toonily.com', popularity: 74, mangaPath: 'webtoons');

  @override
  Future<MangaList> search(String query, int page, FilterValues filters) {
    if (query.trim().isEmpty) return popular(page);
    final q = query.trim().replaceAll(RegExp(r'\s+'), '-');
    return listFrom('$baseUrl/search/${Uri.encodeComponent(q)}/page/$page/');
  }
}

/// Weeb Central — large catalogue, HTML fragments (htmx).
class WeebCentral extends MangaSource {
  @override
  String get id => 'weebcentral';
  @override
  String get name => 'Weeb Central';
  @override
  String get lang => 'en';
  @override
  String get baseUrl => 'https://weebcentral.com';
  @override
  int get popularity => 92;

  Future<MangaList> _list(String extra, int page) async {
    final doc = html.parse(await Net.getText(
      '$baseUrl/search/data?limit=32&offset=${(page - 1) * 32}&official=Any&anime=Any&adult=Any&display_mode=Full%20Display$extra',
    ));
    final seen = <String>{};
    final items = <SourceManga>[];
    for (final article in doc.querySelectorAll('article')) {
      final a = article.querySelector('a[href*="/series/"]');
      final href = a?.attributes['href'];
      if (href == null || !seen.add(href)) continue;
      items.add(SourceManga(
        sourceId: id,
        url: href.replaceFirst(baseUrl, ''),
        title: (article.querySelector('div.text-ellipsis.truncate') ?? article.querySelector('h2, strong'))?.text.trim() ?? '?',
        cover: _src(article.querySelector('picture img') ?? article.querySelector('img')),
      ));
    }
    return MangaList(items, hasNext: items.length >= 30);
  }

  @override
  Future<MangaList> popular(int page) => _list('&sort=Popularity&order=Descending', page);

  @override
  Future<MangaList> search(String query, int page, FilterValues filters) => query.trim().isEmpty
      ? popular(page)
      : _list('&sort=Best%20Match&order=Descending&text=${Uri.encodeQueryComponent(query.trim())}', page);

  @override
  Future<SourceManga> details(SourceManga manga) async {
    final doc = html.parse(await Net.getText('$baseUrl${manga.url}'));
    String? field(String label) {
      for (final s in doc.querySelectorAll('strong')) {
        if (s.text.contains(label)) return s.parent?.text.replaceFirst(s.text, '').trim();
      }
      return null;
    }

    return manga.copyWith(
      description: doc.querySelector('p.whitespace-pre-wrap')?.text.trim(),
      authors: [?field('Author')],
      genres: (field('Tag') ?? '').split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
      status: switch ((field('Status') ?? '').toLowerCase()) {
        final s when s.contains('ongoing') => MangaStatus.ongoing,
        final s when s.contains('complete') => MangaStatus.completed,
        final s when s.contains('hiatus') => MangaStatus.hiatus,
        _ => MangaStatus.unknown,
      },
    );
  }

  @override
  Future<List<Chapter>> chapters(SourceManga manga) async {
    final seriesId = manga.url.split('/').where((s) => s.isNotEmpty).elementAt(1);
    final doc = html.parse(await Net.getText('$baseUrl/series/$seriesId/full-chapter-list'));
    final out = [
      for (final a in doc.querySelectorAll('a[href*="/chapters/"]'))
        Chapter(
          url: a.attributes['href']!.replaceFirst(baseUrl, ''),
          name: (a.querySelector('span')?.text ?? a.text).replaceAll(RegExp(r'\s+'), ' ').trim(),
          number: parseChapterNumber(a.querySelector('span')?.text ?? a.text),
          date: DateTime.tryParse(a.querySelector('time')?.attributes['datetime'] ?? ''),
        ),
    ];
    return out.reversed.toList();
  }

  @override
  Future<List<PageImage>> pages(Chapter chapter) async {
    final doc = html.parse(await Net.getText('$baseUrl${chapter.url}/images?is_prev=False&current_page=1&reading_style=long_strip'));
    return [for (final img in doc.querySelectorAll('img')) if (_src(img) case final s? when s.startsWith('http')) PageImage(s)];
  }
}

/// MangaHub — GraphQL API.
class MangaHub extends MangaSource {
  @override
  String get id => 'mangahub';
  @override
  String get name => 'MangaHub';
  @override
  String get lang => 'en';
  @override
  String get baseUrl => 'https://mangahub.io';
  @override
  int get popularity => 86;

  static const _api = 'https://api.mghcdn.com/graphql';

  Future<Map<String, dynamic>> _query(String q) async {
    final body = jsonDecode(await _post(_api, jsonEncode({'query': q}), headers: {'Origin': baseUrl, 'Referer': '$baseUrl/'}));
    return (body['data'] as Map<String, dynamic>?) ?? const {};
  }

  SourceManga _row(Map<String, dynamic> r) => SourceManga(
        sourceId: id,
        url: r['slug'] as String,
        title: r['title'] as String,
        cover: r['image'] == null ? null : 'https://thumb.mghcdn.com/${r['image']}',
      );

  Future<MangaList> _search(String q, int page) async {
    final data = await _query(
      '{search(x:m01,q:${jsonEncode(q)},genre:"all",mod:POPULAR,limit:30,offset:${(page - 1) * 30}){rows{id,title,slug,image}}}',
    );
    final rows = (data['search']?['rows'] as List? ?? const []);
    return MangaList([for (final r in rows) _row(r as Map<String, dynamic>)], hasNext: rows.length >= 30);
  }

  @override
  Future<MangaList> popular(int page) => _search('', page);

  @override
  Future<MangaList> search(String query, int page, FilterValues filters) => _search(query.trim(), page);

  Future<Map<String, dynamic>> _manga(String slug) async =>
      ((await _query('{manga(x:m01,slug:${jsonEncode(slug)}){title,status,image,author,genres,description,chapters{number,title,date}}}'))['manga']
          as Map<String, dynamic>?) ??
      const {};

  @override
  Future<SourceManga> details(SourceManga manga) async {
    final m = await _manga(manga.url);
    return manga.copyWith(
      description: m['description'] as String?,
      authors: [if (m['author'] != null) m['author'] as String],
      genres: (m['genres'] as String? ?? '').split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
      status: (m['status'] as String? ?? '').contains('ongoing') ? MangaStatus.ongoing : MangaStatus.completed,
    );
  }

  @override
  Future<List<Chapter>> chapters(SourceManga manga) async {
    final m = await _manga(manga.url);
    final out = [
      for (final c in (m['chapters'] as List? ?? const []))
        Chapter(
          url: '${manga.url}|${c['number']}',
          name: 'Chapter ${_fmt(c['number'])}',
          title: (c['title'] as String?)?.isEmpty ?? true ? null : c['title'] as String,
          number: (c['number'] as num?)?.toDouble(),
          date: DateTime.tryParse(c['date'] as String? ?? ''),
        ),
    ];
    out.sort((a, b) => (a.number ?? 0).compareTo(b.number ?? 0));
    return out;
  }

  static String _fmt(Object? n) => n is num && n == n.roundToDouble() ? '${n.toInt()}' : '$n';

  @override
  Future<List<PageImage>> pages(Chapter chapter) async {
    final parts = chapter.url.split('|');
    final data = await _query('{chapter(x:m01,slug:${jsonEncode(parts[0])},number:${parts[1]}){pages}}');
    final pages = jsonDecode(data['chapter']?['pages'] as String? ?? '{}') as Map<String, dynamic>;
    final prefix = pages['p'] as String? ?? '';
    return [for (final i in (pages['i'] as List? ?? const [])) PageImage('https://imgx.mghcdn.com/$prefix$i')];
  }
}

/// Atsumaru (atsu.moe) — JSON API; images live on the CDN host.
class Atsumaru extends MangaSource {
  @override
  String get id => 'atsumaru';
  @override
  String get name => 'Atsumaru';
  @override
  String get lang => 'en';
  @override
  String get baseUrl => 'https://atsu.moe';
  @override
  int get popularity => 80;

  static const _cdn = 'https://cdn.atsu.moe';
  String _img(String? path) => path == null ? '' : (path.startsWith('http') ? path : '$_cdn${path.startsWith('/') ? '' : '/'}$path');

  Future<MangaList> _search(String q, int page) async {
    final json = await Net.getJson(
      '$baseUrl/collections/manga/documents/search?q=${Uri.encodeQueryComponent(q.isEmpty ? '*' : q)}'
      '&query_by=title,englishTitle,otherNames&sort_by=views:desc&filter_by=isAdult:false&per_page=24&page=$page',
    );
    final hits = json['hits'] as List? ?? const [];
    return MangaList([
      for (final h in hits)
        SourceManga(
          sourceId: id,
          url: h['document']['id'] as String,
          title: (h['document']['englishTitle'] ?? h['document']['title']) as String,
          cover: _img(h['document']['poster'] as String? ?? h['document']['image'] as String?),
        ),
    ], hasNext: hits.length >= 24);
  }

  @override
  Future<MangaList> popular(int page) => _search('', page);

  @override
  Future<MangaList> search(String query, int page, FilterValues filters) => _search(query.trim(), page);

  @override
  Future<SourceManga> details(SourceManga manga) async {
    final p = (await Net.getJson('$baseUrl/api/manga/page?id=${manga.url}'))['mangaPage'] as Map<String, dynamic>? ?? const {};
    final poster = p['poster'];
    return manga.copyWith(
      description: p['synopsis'] as String?,
      cover: poster is String ? _img(poster) : (poster is Map ? _img(poster['image'] as String?) : manga.cover),
      authors: [for (final a in (p['authors'] as List? ?? const [])) (a is Map ? a['name'] : a).toString()],
      genres: [for (final t in (p['tags'] as List? ?? const [])) (t is Map ? t['name'] : t).toString()],
      status: '${p['status']}'.toLowerCase().contains('ongoing') ? MangaStatus.ongoing : MangaStatus.unknown,
    );
  }

  @override
  Future<List<Chapter>> chapters(SourceManga manga) async {
    final json = await Net.getJson('$baseUrl/api/manga/allChapters?mangaId=${manga.url}');
    final byNumber = <num, Chapter>{};
    for (final c in json['chapters'] as List? ?? const []) {
      final n = c['number'] as num? ?? 0;
      // Several scanlators may release the same chapter: keep one per number.
      byNumber.putIfAbsent(
        n,
        () => Chapter(url: '${manga.url}|${c['id']}', name: (c['title'] as String?) ?? 'Chapter $n', number: n.toDouble(), date: DateTime.tryParse('${c['createdAt']}')),
      );
    }
    return byNumber.values.toList()..sort((a, b) => (a.number ?? 0).compareTo(b.number ?? 0));
  }

  @override
  Future<List<PageImage>> pages(Chapter chapter) async {
    final parts = chapter.url.split('|');
    final json = await Net.getJson('$baseUrl/api/read/chapter?mangaId=${parts[0]}&chapterId=${parts[1]}');
    return [for (final p in (json['readChapter']?['pages'] as List? ?? const [])) PageImage(_img(p['image'] as String?))];
  }
}

/// MangaKatana — page list hidden among decoy JS arrays.
class MangaKatana extends MangaSource {
  @override
  String get id => 'mangakatana';
  @override
  String get name => 'MangaKatana';
  @override
  String get lang => 'en';
  @override
  String get baseUrl => 'https://mangakatana.com';
  @override
  int get popularity => 78;

  Future<MangaList> _list(String url) async {
    final doc = html.parse(await Net.getText(url));
    final items = [
      for (final item in doc.querySelectorAll('#book_list .item'))
        if (item.querySelector('.text h3.title a') case final a?)
          SourceManga(sourceId: id, url: a.attributes['href']!.replaceFirst(baseUrl, ''), title: a.text.trim(), cover: _src(item.querySelector('.wrap_img img'))),
    ];
    return MangaList(items, hasNext: items.length >= 18);
  }

  @override
  Future<MangaList> popular(int page) => _list('$baseUrl/manga/page/$page?filter=1&order=numc');

  @override
  Future<MangaList> search(String query, int page, FilterValues filters) => query.trim().isEmpty
      ? popular(page)
      : _list('$baseUrl/page/$page?search=${Uri.encodeQueryComponent(query.trim())}&search_by=m_name');

  @override
  Future<SourceManga> details(SourceManga manga) async {
    final doc = html.parse(await Net.getText('$baseUrl${manga.url}'));
    return manga.copyWith(
      description: doc.querySelector('.summary > p, .summary')?.text.trim(),
      cover: _src(doc.querySelector('.cover img')) ?? manga.cover,
      authors: [for (final a in doc.querySelectorAll('.author')) a.text.trim()],
      genres: [for (final a in doc.querySelectorAll('.genres a')) a.text.trim()],
      status: (doc.querySelector('.value.status')?.text ?? '').toLowerCase().contains('ongoing') ? MangaStatus.ongoing : MangaStatus.completed,
    );
  }

  @override
  Future<List<Chapter>> chapters(SourceManga manga) async {
    final doc = html.parse(await Net.getText('$baseUrl${manga.url}'));
    final out = [
      for (final a in doc.querySelectorAll('div.chapter a'))
        Chapter(url: a.attributes['href']!.replaceFirst(baseUrl, ''), name: a.text.trim(), number: parseChapterNumber(a.text)),
    ];
    return out.reversed.toList();
  }

  @override
  Future<List<PageImage>> pages(Chapter chapter) async {
    final text = await Net.getText('$baseUrl${chapter.url}');
    final name = RegExp(r'''data-src['"],\s*(\w+)''').firstMatch(text)?.group(1);
    if (name == null) return const [];
    final array = RegExp('var $name\\s*=\\s*\\[(.*?)\\]', dotAll: true).firstMatch(text)?.group(1) ?? '';
    return [for (final m in RegExp(r'''['"](https?://[^'"]+)['"]''').allMatches(array)) PageImage(m.group(1)!)];
  }
}
