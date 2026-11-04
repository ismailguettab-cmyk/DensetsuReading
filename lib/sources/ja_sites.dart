import 'package:html/parser.dart' as html;

import '../core/net.dart';
import 'source.dart';

// Japanese raw sources (one class each).

/// Rawdevart — clean JSON API (mirrors: rawuwu.net, rawsakura.org).
class Rawdevart extends MangaSource {
  @override
  String get id => 'rawdevart';
  @override
  String get name => 'Rawdevart';
  @override
  String get lang => 'ja';
  @override
  String get baseUrl => 'https://rawdevart.art';
  @override
  int get popularity => 85;

  SourceManga _parse(Map<String, dynamic> m) => SourceManga(
        sourceId: id,
        url: '${m['manga_id']}',
        title: (m['manga_name'] as String? ?? '?').trim(),
        cover: m['manga_cover_img'] as String?,
        description: m['manga_description'] as String?,
        status: m['manga_status'] == true ? MangaStatus.completed : MangaStatus.ongoing,
        altTitles: (m['manga_others_name'] as String? ?? '').split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
      );

  Future<MangaList> _list(String url) async {
    final json = await Net.getJson(url);
    final items = [for (final m in json['manga_list'] as List? ?? const []) _parse(m as Map<String, dynamic>)];
    final next = json['pagi']?['button']?['next'];
    return MangaList(items, hasNext: next != null && next != 0);
  }

  @override
  Future<MangaList> popular(int page) => _list('$baseUrl/spa/genre/all?page=$page&sort=most_viewed');

  @override
  Future<MangaList> search(String query, int page, FilterValues filters) => query.trim().isEmpty
      ? popular(page)
      : _list('$baseUrl/spa/search?page=$page&query=${Uri.encodeQueryComponent(query.trim())}');

  @override
  Future<SourceManga> details(SourceManga manga) async {
    final detail = (await Net.getJson('$baseUrl/spa/manga/${manga.url}'))['detail'] as Map<String, dynamic>;
    final parsed = _parse(detail);
    return parsed.copyWith(cover: parsed.cover ?? manga.cover);
  }

  @override
  Future<List<Chapter>> chapters(SourceManga manga) async {
    final json = await Net.getJson('$baseUrl/spa/manga/${manga.url}');
    final out = [
      for (final c in json['chapters'] as List? ?? const [])
        Chapter(
          url: '${manga.url}/${c['chapter_number']}',
          name: '第${_fmt(c['chapter_number'])}話',
          title: (c['chapter_title'] as String?)?.trim().isEmpty ?? true ? null : c['chapter_title'] as String,
          number: (c['chapter_number'] as num?)?.toDouble(),
          date: DateTime.tryParse(c['chapter_date_published'] as String? ?? ''),
        ),
    ];
    out.sort((a, b) => (a.number ?? 0).compareTo(b.number ?? 0));
    return out;
  }

  static String _fmt(Object? n) => n is num && n == n.roundToDouble() ? '${n.toInt()}' : '$n';

  @override
  Future<List<PageImage>> pages(Chapter chapter) async {
    final detail = (await Net.getJson('$baseUrl/spa/manga/${chapter.url}'))['chapter_detail'] as Map<String, dynamic>;
    final server = (detail['server'] as String? ?? '').replaceAll(RegExp(r'/$'), '');
    final doc = html.parse(detail['chapter_content'] as String? ?? '');
    return [
      for (final img in doc.querySelectorAll('img'))
        if ((img.attributes['data-src'] ?? img.attributes['src']) case final src?)
          PageImage(src.startsWith('http') ? src : '$server/${src.replaceAll(RegExp(r'^/'), '')}'),
    ];
  }
}

/// MangaRW — titles in Japanese.
class MangaRW extends MangaSource {
  @override
  String get id => 'mangarw';
  @override
  String get name => 'MangaRW';
  @override
  String get lang => 'ja';
  @override
  String get baseUrl => 'https://mangarw.com';
  @override
  int get popularity => 70;

  Future<MangaList> _list(String url) async {
    final doc = html.parse(await Net.getText(url));
    final seen = <String>{};
    final items = [
      for (final a in doc.querySelectorAll('a[href^="/manga/"]'))
        if (a.querySelector('img') != null && seen.add(a.attributes['href']!))
          SourceManga(
            sourceId: id,
            url: a.attributes['href']!,
            title: (a.attributes['title'] ?? a.querySelector('img')?.attributes['alt'] ?? '?').trim(),
            cover: a.querySelector('img')?.attributes['data-src'] ?? a.querySelector('img')?.attributes['src'],
          ),
    ];
    return MangaList(items, hasNext: items.length >= 20);
  }

  @override
  Future<MangaList> popular(int page) => _list('$baseUrl/browse?page=$page');

  @override
  Future<MangaList> search(String query, int page, FilterValues filters) =>
      _list('$baseUrl/browse?page=$page&q=${Uri.encodeQueryComponent(query.trim())}');

  @override
  Future<SourceManga> details(SourceManga manga) async {
    final doc = html.parse(await Net.getText('$baseUrl${manga.url}'));
    final desc = doc.querySelectorAll('p').map((p) => p.text.trim()).where((t) => t.length > 60).firstOrNull;
    return manga.copyWith(description: desc);
  }

  @override
  Future<List<Chapter>> chapters(SourceManga manga) async {
    final id = manga.url.split('/').where((s) => s.isNotEmpty).last;
    final doc = html.parse(await Net.getText('$baseUrl/api/v1/chapters?id=$id'));
    final out = [
      for (final o in doc.querySelectorAll('option'))
        Chapter(url: '/read?id=${o.attributes['value']}', name: o.text.trim(), number: parseChapterNumber(o.text)),
    ];
    out.sort((a, b) => (a.number ?? 0).compareTo(b.number ?? 0));
    return out;
  }

  @override
  Future<List<PageImage>> pages(Chapter chapter) async {
    final doc = html.parse(await Net.getText('$baseUrl${chapter.url}'));
    return [
      for (final img in doc.querySelectorAll('img'))
        if ((img.attributes['data-src'] ?? img.attributes['src'] ?? '').contains('mangabuzz'))
          PageImage((img.attributes['data-src'] ?? img.attributes['src'])!),
    ];
  }
}

/// Raw1001 (Liliana theme): page order comes from data-index, not the DOM.
class Raw1001 extends MangaSource {
  @override
  String get id => 'raw1001';
  @override
  String get name => 'Raw1001';
  @override
  String get lang => 'ja';
  @override
  String get baseUrl => 'https://raw1001.net';
  @override
  int get popularity => 62;

  Future<MangaList> _list(String url) async {
    final doc = html.parse(await Net.getText(url));
    final seen = <String>{};
    final items = <SourceManga>[];
    for (final a in doc.querySelectorAll('a[href*="/manga/"]')) {
      final href = a.attributes['href']!.replaceFirst(baseUrl, '');
      final title = (a.attributes['title'] ?? a.text).trim();
      if (title.isEmpty || href.split('/').where((s) => s.isNotEmpty).length != 2 || !seen.add(href)) continue;
      final img = a.querySelector('img') ?? a.parent?.querySelector('img');
      items.add(SourceManga(
        sourceId: id,
        url: href,
        title: title,
        cover: img?.attributes['data-src'] ?? img?.attributes['src'],
      ));
    }
    return MangaList(items, hasNext: items.length >= 10);
  }

  @override
  Future<MangaList> popular(int page) => _list('$baseUrl/ranking/week/$page');

  @override
  Future<MangaList> search(String query, int page, FilterValues filters) => query.trim().isEmpty
      ? popular(page)
      : _list('$baseUrl/search/$page/?keyword=${Uri.encodeQueryComponent(query.trim())}');

  @override
  Future<SourceManga> details(SourceManga manga) async {
    final doc = html.parse(await Net.getText('$baseUrl${manga.url}'));
    final og = doc.querySelector('meta[property="og:image"]')?.attributes['content'];
    final desc = doc.querySelector('meta[name="description"]')?.attributes['content'];
    return manga.copyWith(cover: og ?? manga.cover, description: desc);
  }

  @override
  Future<List<Chapter>> chapters(SourceManga manga) async {
    final doc = html.parse(await Net.getText('$baseUrl${manga.url}'));
    final out = [
      for (final a in doc.querySelectorAll('li.chapter a'))
        Chapter(
          url: a.attributes['href']!.replaceFirst(baseUrl, ''),
          name: a.text.replaceAll(RegExp(r'\s+'), ' ').trim(),
          number: parseChapterNumber(a.text),
        ),
    ];
    out.sort((a, b) => (a.number ?? 0).compareTo(b.number ?? 0));
    return out;
  }

  @override
  Future<List<PageImage>> pages(Chapter chapter) async {
    final page = await Net.getText('$baseUrl${chapter.url}');
    final id = RegExp(r'const CHAPTER_ID = (\d+);').firstMatch(page)?.group(1);
    if (id == null) return const [];
    final json = await Net.getJson('$baseUrl/ajax/image/list/chap/$id', headers: {'Referer': '$baseUrl${chapter.url}'});
    final doc = html.parse(json['html'] as String? ?? '');
    final pages = [
      for (final d in doc.querySelectorAll('div.separator[data-index]'))
        if (d.querySelector('a')?.attributes['href'] case final href?) (int.tryParse(d.attributes['data-index']!) ?? 0, href),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    return [for (final p in pages) PageImage(p.$2)];
  }
}
