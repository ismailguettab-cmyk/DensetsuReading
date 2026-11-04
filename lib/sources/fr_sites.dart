import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;

import '../core/net.dart';
import 'source.dart';

// French sites with their own engine (one class each).

String _abs(String base, String href) => href.startsWith('http') ? href : '$base${href.startsWith('/') ? '' : '/'}$href';
String _rel(String base, String href) => href.startsWith(base) ? href.substring(base.length) : href;
String? _src(Element? img) =>
    (img?.attributes['data-src'] ?? img?.attributes['data-lazy-src'] ?? img?.attributes['src'])?.trim();

MangaStatus _status(String? s) {
  final v = (s ?? '').toLowerCase();
  if (v.contains('cours') || v.contains('ongoing')) return MangaStatus.ongoing;
  if (v.contains('termin') || v.contains('complet') || v.contains('fini')) return MangaStatus.completed;
  if (v.contains('pause') || v.contains('hiatus')) return MangaStatus.hiatus;
  if (v.contains('abandon') || v.contains('annul')) return MangaStatus.cancelled;
  return MangaStatus.unknown;
}

/// FMTeam — PizzaReader JSON API (small, clean catalogue).
class FMTeam extends MangaSource {
  @override
  String get id => 'fmteam';
  @override
  String get name => 'FMTeam';
  @override
  String get lang => 'fr';
  @override
  String get baseUrl => 'https://fmteam.fr';
  @override
  int get popularity => 60;

  SourceManga _parse(Map<String, dynamic> c) => SourceManga(
        sourceId: id,
        url: c['slug'] as String,
        title: c['title'] as String,
        cover: c['thumbnail'] as String?,
        description: c['description'] as String?,
        authors: [if (c['author'] != null) c['author'] as String],
        genres: [for (final g in (c['genres'] as List? ?? const [])) (g['name'] as String)],
        status: _status(c['status'] as String?),
        altTitles: (c['alt_titles'] as List? ?? const []).cast<String>(),
      );

  @override
  Future<MangaList> popular(int page) async {
    if (page > 1) return const MangaList([]);
    final json = await Net.getJson('$baseUrl/api/comics');
    return MangaList([for (final c in json['comics'] as List) _parse(c as Map<String, dynamic>)]);
  }

  @override
  Future<MangaList> search(String query, int page, FilterValues filters) async {
    if (query.trim().isEmpty) return popular(page);
    if (page > 1) return const MangaList([]);
    final json = await Net.getJson('$baseUrl/api/search/${Uri.encodeComponent(query.trim())}');
    return MangaList([for (final c in json['comics'] as List? ?? const []) _parse(c as Map<String, dynamic>)]);
  }

  @override
  Future<SourceManga> details(SourceManga manga) async =>
      _parse((await Net.getJson('$baseUrl/api/comics/${manga.url}'))['comic'] as Map<String, dynamic>);

  @override
  Future<List<Chapter>> chapters(SourceManga manga) async {
    final json = await Net.getJson('$baseUrl/api/comics/${manga.url}');
    final out = [
      for (final c in (json['comic']['chapters'] as List? ?? const []))
        Chapter(
          url: c['url'] as String,
          name: (c['full_title'] as String?) ?? 'Chapitre ${c['chapter']}',
          number: (c['chapter'] as num?)?.toDouble(),
          volume: c['volume']?.toString(),
          date: DateTime.tryParse(c['published_on'] as String? ?? ''),
        ),
    ];
    out.sort((a, b) => (a.number ?? 0).compareTo(b.number ?? 0));
    return out;
  }

  @override
  Future<List<PageImage>> pages(Chapter chapter) async {
    final json = await Net.getJson('$baseUrl/api${chapter.url}');
    return [for (final p in (json['chapter']['pages'] as List)) PageImage(p as String)];
  }
}

/// Anime-Sama (scans section): images follow a fixed pattern per chapter.
class AnimeSama extends MangaSource {
  @override
  String get id => 'animesama';
  @override
  String get name => 'Anime-Sama';
  @override
  String get lang => 'fr';
  @override
  String get baseUrl => 'https://anime-sama.to';
  @override
  int get popularity => 92;

  List<SourceManga> _cards(Document doc) => [
        for (final a in doc.querySelectorAll('#list_catalog a.as-carte-lien'))
          SourceManga(
            sourceId: id,
            url: _rel(baseUrl, a.attributes['href']!),
            title: a.querySelector('.as-carte-titre')?.text.trim() ?? '?',
            cover: _src(a.querySelector('.as-carte-image img')),
          ),
      ];

  @override
  Future<MangaList> popular(int page) => search('', page, const {});

  @override
  Future<MangaList> search(String query, int page, FilterValues filters) async {
    final q = query.trim().isEmpty ? '' : '&search=${Uri.encodeQueryComponent(query.trim())}';
    final doc = html.parse(await Net.getText('$baseUrl/catalogue/?type%5B%5D=Scans&page=$page$q'));
    final items = _cards(doc);
    return MangaList(items, hasNext: items.length >= 40);
  }

  @override
  Future<SourceManga> details(SourceManga manga) async {
    final doc = html.parse(await Net.getText('$baseUrl${manga.url.endsWith('/') ? manga.url : '${manga.url}/'}'));
    return manga.copyWith(
      description: doc.querySelector('#synopsisText')?.text.trim(),
      cover: _src(doc.querySelector('#coverOeuvre')) ?? manga.cover,
      genres: [for (final a in doc.querySelectorAll('a[href*="genre"]')) a.text.trim()].where((g) => g.isNotEmpty).take(8).toList(),
    );
  }

  @override
  Future<List<Chapter>> chapters(SourceManga manga) async {
    final page = await Net.getText('$baseUrl${manga.url.endsWith('/') ? manga.url : '${manga.url}/'}');
    final title = html.parse(page).querySelector('#titreOeuvre')?.text.trim() ?? manga.title;
    final counts = await Net.getJson('$baseUrl/s2/scans/get_nb_chap_et_img.php?oeuvre=${Uri.encodeQueryComponent(title)}');
    if (counts is! Map) return const [];
    final out = <Chapter>[];
    counts.forEach((k, v) {
      final n = double.tryParse('$k');
      if (n == null || v is! num || v <= 0) return; // e.g. {"error": …} for titles without scans
      // The chapter "url" carries what the page list needs: title, chapter key and page count.
      out.add(Chapter(url: '$title|$k|$v', name: 'Chapitre $k', number: n));
    });
    out.sort((a, b) => (a.number ?? 0).compareTo(b.number ?? 0));
    return out;
  }

  @override
  Future<List<PageImage>> pages(Chapter chapter) async {
    final parts = chapter.url.split('|');
    final count = int.tryParse(parts[2]) ?? 0;
    final title = Uri.encodeComponent(parts[0]);
    return [for (var i = 1; i <= count; i++) PageImage('$baseUrl/s2/scans/$title/${parts[1]}/$i.jpg')];
  }
}

/// LelscanFR (FuzzyDoodle theme): paginated chapter lists.
class LelscanFR extends MangaSource {
  @override
  String get id => 'lelscanfr';
  @override
  String get name => 'LelscanFR';
  @override
  String get lang => 'fr';
  @override
  String get baseUrl => 'https://www.lelscanfr.com';
  @override
  int get popularity => 72;

  Future<MangaList> _list(String url) async {
    final doc = html.parse(await Net.getText(url));
    final items = [
      for (final card in doc.querySelectorAll('div#card-real'))
        if (card.querySelector('a') != null)
          SourceManga(
            sourceId: id,
            url: _rel(baseUrl, card.querySelector('a')!.attributes['href']!),
            title: card.querySelector('h2')?.text.trim() ?? '?',
            cover: _src(card.querySelector('img')),
          ),
    ];
    return MangaList(items, hasNext: items.length >= 20);
  }

  @override
  Future<MangaList> popular(int page) => _list('$baseUrl/manga?page=$page');

  @override
  Future<MangaList> search(String query, int page, FilterValues filters) =>
      _list('$baseUrl/manga?title=${Uri.encodeQueryComponent(query.trim())}&page=$page');

  @override
  Future<SourceManga> details(SourceManga manga) async {
    final doc = html.parse(await Net.getText('$baseUrl${manga.url}'));
    final desc = doc.querySelectorAll('p').map((p) => p.text.trim()).where((t) => t.length > 120).firstOrNull;
    return manga.copyWith(description: desc, cover: _src(doc.querySelector('img[alt="${manga.title}"]')) ?? manga.cover);
  }

  @override
  Future<List<Chapter>> chapters(SourceManga manga) async {
    final out = <Chapter>[];
    for (var page = 1; page <= 30; page++) {
      final doc = html.parse(await Net.getText('$baseUrl${manga.url}?page=$page'));
      final links = doc.querySelectorAll('div#chapters-list > a[href]');
      for (final a in links) {
        final name = a.text.replaceAll(RegExp(r'\s+'), ' ').trim();
        out.add(Chapter(url: _rel(baseUrl, a.attributes['href']!), name: name, number: parseChapterNumber(a.attributes['href']!)));
      }
      final next = doc.querySelector('ul.pagination > li:last-child');
      if (links.isEmpty || next == null || next.classes.contains('pagination-disabled')) break;
    }
    out.sort((a, b) => (a.number ?? 0).compareTo(b.number ?? 0));
    return out;
  }

  @override
  Future<List<PageImage>> pages(Chapter chapter) async {
    final doc = html.parse(await Net.getText('$baseUrl${chapter.url}'));
    return [
      for (final img in doc.querySelectorAll('div#chapter-container > img'))
        if (_src(img) != null) PageImage(_abs(baseUrl, _src(img)!)),
    ];
  }
}

/// Scantrad Union: its image host refuses requests that carry a Referer.
class ScantradUnion extends MangaSource {
  @override
  String get id => 'scantradunion';
  @override
  String get name => 'Scantrad Union';
  @override
  String get lang => 'fr';
  @override
  String get baseUrl => 'https://scantrad-union.com';
  @override
  int get popularity => 70;

  static String? _bg(Element? e) => RegExp(r'''url\(['"]?([^'")]+)''').firstMatch(e?.attributes['style'] ?? '')?.group(1);

  @override
  Future<MangaList> popular(int page) async {
    if (page > 1) return const MangaList([]);
    final doc = html.parse(await Net.getText('$baseUrl/projets/'));
    return MangaList([
      for (final a in doc.querySelectorAll('a.index-top3-a'))
        SourceManga(
          sourceId: id,
          url: _rel(baseUrl, a.attributes['href']!),
          title: a.querySelector('.index-top3-title')?.text.trim() ?? '?',
          cover: _bg(a.querySelector('[style*="background-image"]')) ?? _bg(a),
        ),
    ]);
  }

  @override
  Future<MangaList> search(String query, int page, FilterValues filters) async {
    if (query.trim().isEmpty) return popular(page);
    if (page > 1) return const MangaList([]);
    final doc = html.parse(await Net.getText('$baseUrl/?s=${Uri.encodeQueryComponent(query.trim())}'));
    return MangaList([
      for (final a in doc.querySelectorAll('article.post-outer a.index-post-header-a'))
        if ((a.attributes['href'] ?? '').contains('/manga/'))
          SourceManga(
            sourceId: id,
            url: _rel(baseUrl, a.attributes['href']!),
            title: a.text.trim().isNotEmpty ? a.text.trim() : (a.attributes['title'] ?? '?'),
            cover: _src(a.querySelector('img')) ?? _bg(a.querySelector('[style*="background-image"]')),
          ),
    ]);
  }

  @override
  Future<SourceManga> details(SourceManga manga) async {
    final doc = html.parse(await Net.getText('$baseUrl${manga.url}'));
    final desc = doc.querySelector('.sContent, .synopsis, .project-synopsis, .entry-content p');
    return manga.copyWith(description: desc?.text.trim(), cover: _src(doc.querySelector('.projet-image img, .project-image img')) ?? manga.cover);
  }

  @override
  Future<List<Chapter>> chapters(SourceManga manga) async {
    final doc = html.parse(await Net.getText('$baseUrl${manga.url}'));
    final out = <Chapter>[];
    for (final li in doc.querySelectorAll('.links-projects li')) {
      final read = li.querySelectorAll('a.btnlel').where((a) => (a.attributes['href'] ?? '').contains('/read/')).firstOrNull;
      if (read == null) continue;
      final number = li.querySelector('.chapter-number')?.text.trim() ?? '';
      final title = li.querySelector('.chapter-name')?.text.trim();
      out.add(Chapter(
        url: _rel(baseUrl, read.attributes['href']!),
        name: number.isEmpty ? (title ?? 'Chapitre') : 'Chapitre ${number.replaceAll(RegExp(r'[^0-9.,]'), '')}',
        title: (title?.isNotEmpty ?? false) ? title : null,
        number: parseChapterNumber(number.isEmpty ? read.attributes['href']! : number),
      ));
    }
    out.sort((a, b) => (a.number ?? 0).compareTo(b.number ?? 0));
    return out;
  }

  @override
  Future<List<PageImage>> pages(Chapter chapter) async {
    final doc = html.parse(await Net.getText('$baseUrl${chapter.url}'));
    return [
      for (final img in doc.querySelectorAll('#webtoon a img, #webtoon img'))
        if (_src(img) != null) PageImage(_abs(baseUrl, _src(img)!)),
    ];
  }
}

/// DassouScan: premium chapters are skipped.
class DassouScan extends MangaSource {
  @override
  String get id => 'dassouscan';
  @override
  String get name => 'DassouScan';
  @override
  String get lang => 'fr';
  @override
  String get baseUrl => 'https://dassouscan.com';
  @override
  int get popularity => 48;

  Future<MangaList> _list(String url) async {
    final doc = html.parse(await Net.getText(url));
    final items = [
      for (final card in doc.querySelectorAll('article.dsc-cat-card'))
        if (card.querySelector('a.dsc-cat-card__cover-link') != null)
          SourceManga(
            sourceId: id,
            url: _rel(baseUrl, card.querySelector('a.dsc-cat-card__cover-link')!.attributes['href']!),
            title: card.attributes['data-title'] ?? '?',
            cover: _src(card.querySelector('.dsc-cat-card__cover img')),
          ),
    ];
    return MangaList(items, hasNext: items.length >= 12);
  }

  @override
  Future<MangaList> popular(int page) => _list('$baseUrl/catalogue?tri=popular&page=$page');

  @override
  Future<MangaList> search(String query, int page, FilterValues filters) =>
      _list('$baseUrl/catalogue?q=${Uri.encodeQueryComponent(query.trim())}&page=$page');

  @override
  Future<SourceManga> details(SourceManga manga) async {
    final doc = html.parse(await Net.getText('$baseUrl${manga.url}'));
    final desc = doc.querySelectorAll('[class*="synopsis"], [class*="description"]').map((e) => e.text.trim()).where((t) => t.length > 60).firstOrNull;
    return manga.copyWith(description: desc);
  }

  @override
  Future<List<Chapter>> chapters(SourceManga manga) async {
    final doc = html.parse(await Net.getText('$baseUrl${manga.url}'));
    final out = <Chapter>[];
    for (final block in doc.querySelectorAll('div.dsc-manga-chapter-block')) {
      if (block.querySelector('.dsc-ch-hl__access--premium, a.is-locked') != null) continue;
      final a = block.querySelector('a.dsc-manga-chapter-block__title-link');
      final href = a?.attributes['href'] ?? '';
      if (a == null || href.contains('/inscription')) continue;
      final name = a.text.replaceAll(RegExp(r'\s+'), ' ').trim();
      out.add(Chapter(url: _rel(baseUrl, href), name: name, number: parseChapterNumber(href)));
    }
    out.sort((a, b) => (a.number ?? 0).compareTo(b.number ?? 0));
    return out;
  }

  @override
  Future<List<PageImage>> pages(Chapter chapter) async {
    final doc = html.parse(await Net.getText('$baseUrl${chapter.url}'));
    return [
      for (final img in doc.querySelectorAll('#dsc-chapter-reader-content .dsc-chapter-strip-img'))
        if (_src(img) != null) PageImage(_abs(baseUrl, _src(img)!)),
    ];
  }
}
