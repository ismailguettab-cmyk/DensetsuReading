import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

import '../core/net.dart';
import 'source.dart';

/// Engine for WordPress sites on the Madara theme — the most common scanlation
/// theme. Like Tachiyomi's multisrc, each site only provides its settings.
class Madara extends MangaSource {
  Madara({
    required this.id,
    required this.name,
    required this.lang,
    required this.baseUrl,
    required this.popularity,
    this.mangaPath = 'manga',
    this.genres = const [],
    this.chaptersByAjax = true,
  });

  @override
  final String id, name, lang, baseUrl;
  @override
  final int popularity;
  final String mangaPath;
  final List<FilterOption> genres;

  /// Newer Madara versions load chapters with a POST to `{manga}ajax/chapters/`.
  final bool chaptersByAjax;

  @override
  Map<String, String> get imageHeaders => {'Referer': '$baseUrl/'};

  @override
  List<SourceFilter> get filters => [
        const SourceFilter(
          key: 'status',
          fr: 'Statut',
          en: 'Status',
          kind: FilterKind.single,
          options: [
            FilterOption('', 'Tous', 'All'),
            FilterOption('on-going', 'En cours', 'Ongoing'),
            FilterOption('end', 'Terminé', 'Completed'),
          ],
        ),
        const SourceFilter(
          key: 'order',
          fr: 'Trier par',
          en: 'Sort by',
          kind: FilterKind.single,
          options: [
            FilterOption('views', 'Popularité', 'Popularity'),
            FilterOption('latest', 'Mise à jour', 'Latest update'),
            FilterOption('rating', 'Note', 'Rating'),
            FilterOption('alphabet', 'A → Z', 'A → Z'),
          ],
        ),
        if (genres.isNotEmpty) SourceFilter(key: 'genre', fr: 'Catégories', en: 'Categories', kind: FilterKind.multi, options: genres),
      ];

  String _path(String href) => href.startsWith(baseUrl) ? href.substring(baseUrl.length) : href;

  String? _img(Element? img) {
    if (img == null) return null;
    final srcset = img.attributes['data-srcset'] ?? img.attributes['srcset'];
    final src = img.attributes['data-src'] ?? img.attributes['data-lazy-src'] ?? img.attributes['src'];
    final best = (srcset != null && srcset.trim().isNotEmpty) ? srcset.split(',').last.trim().split(' ').first : src;
    return best?.trim();
  }

  List<SourceManga> _cards(Document doc) {
    final out = <SourceManga>[];
    final seen = <String>{};
    for (final card in doc.querySelectorAll('div.page-item-detail, div.c-tabs-item__content, div.manga__item')) {
      final a = card.querySelector('.post-title a, h3 a, h4 a, .manga__content a');
      if (a == null) continue;
      final url = _path(a.attributes['href'] ?? '');
      if (url.isEmpty || !seen.add(url)) continue;
      out.add(SourceManga(sourceId: id, url: url, title: a.text.trim(), cover: _img(card.querySelector('img'))));
    }
    return out;
  }

  Future<MangaList> listFrom(String url) async {
    final doc = html.parse(await Net.getText(url));
    final items = _cards(doc);
    return MangaList(items, hasNext: items.length >= 10 && doc.querySelector('.nav-previous, a.next, .wp-pagenavi a.nextpostslink, .navigation-ajax') != null || items.length >= 18);
  }

  @override
  Future<MangaList> popular(int page) => listFrom('$baseUrl/$mangaPath/page/$page/?m_orderby=views');

  @override
  Future<MangaList> search(String query, int page, FilterValues filters) {
    final params = <String>[
      's=${Uri.encodeQueryComponent(query.trim())}',
      'post_type=wp-manga',
      if ((filters['status'] as String? ?? '').isNotEmpty) 'status%5B%5D=${filters['status']}',
      if ((filters['order'] as String? ?? '').isNotEmpty) 'm_orderby=${filters['order']}',
      for (final g in (filters['genre'] as Set<String>? ?? const {})) 'genre%5B%5D=$g',
    ];
    return listFrom('$baseUrl/page/$page/?${params.join('&')}');
  }

  @override
  Future<SourceManga> details(SourceManga manga) async {
    final doc = html.parse(await Net.getText('$baseUrl${manga.url}'));
    String? field(String label) {
      for (final item in doc.querySelectorAll('.post-content_item, .post-status .post-content_item')) {
        final head = item.querySelector('.summary-heading')?.text.trim().toLowerCase() ?? '';
        if (head.contains(label)) return item.querySelector('.summary-content')?.text.trim();
      }
      return null;
    }

    final status = (field('statu') ?? '').toLowerCase();
    return manga.copyWith(
      cover: _img(doc.querySelector('.summary_image img')) ?? manga.cover,
      description: (doc.querySelector('.description-summary .summary__content, .summary__content, .manga-excerpt, .manga-summary'))?.text.trim(),
      authors: [for (final a in doc.querySelectorAll('.author-content a')) a.text.trim()],
      genres: [for (final a in doc.querySelectorAll('.genres-content a')) a.text.trim()],
      status: status.contains('going') || status.contains('cours') || status.contains('連載')
          ? MangaStatus.ongoing
          : status.contains('complet') || status.contains('termin') || status.contains('end') || status.contains('完結')
              ? MangaStatus.completed
              : MangaStatus.unknown,
    );
  }

  @override
  Future<List<Chapter>> chapters(SourceManga manga) async {
    var doc = html.parse(await Net.getText('$baseUrl${manga.url}'));
    var items = doc.querySelectorAll('li.wp-manga-chapter');
    if (items.isEmpty && chaptersByAjax) {
      final url = '$baseUrl${manga.url.endsWith('/') ? manga.url : '${manga.url}/'}ajax/chapters/';
      doc = html.parse(await _post(url, ''));
      items = doc.querySelectorAll('li.wp-manga-chapter');
    }
    if (items.isEmpty) {
      final postId = doc.querySelector('#manga-chapters-holder')?.attributes['data-id'];
      if (postId != null) {
        doc = html.parse(await _post('$baseUrl/wp-admin/admin-ajax.php', 'action=manga_get_chapters&manga=$postId'));
        items = doc.querySelectorAll('li.wp-manga-chapter');
      }
    }
    final out = <Chapter>[];
    for (final li in items) {
      final a = li.querySelector('a');
      if (a == null) continue;
      final name = a.text.replaceAll(RegExp(r'\s+'), ' ').trim();
      out.add(Chapter(url: _path(a.attributes['href'] ?? ''), name: name, number: parseChapterNumber(name)));
    }
    return out.reversed.toList();
  }

  /// Madara's AJAX endpoints only take POST; on the web preview the relay forwards it.
  Future<String> _post(String url, String body) async {
    final uri = kIsWeb ? Uri(path: '/proxy', queryParameters: {'url': url, 'referer': '$baseUrl/'}) : Uri.parse(url);
    final res = await http.post(
      uri,
      headers: {
        ...Net.nativeHeaders(url, {'Referer': '$baseUrl/', 'X-Requested-With': 'XMLHttpRequest'}),
        'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
      },
      body: body,
    );
    if (res.statusCode >= 400) throw HttpError(res.statusCode, url);
    return res.body;
  }

  @override
  Future<List<PageImage>> pages(Chapter chapter) async {
    final sep = chapter.url.contains('?') ? '&' : '?';
    final doc = html.parse(await Net.getText('$baseUrl${chapter.url}${sep}style=list'));
    return [
      for (final img in doc.querySelectorAll('div.page-break img, .reading-content img'))
        if (_img(img) != null && _img(img)!.startsWith('http')) PageImage(_img(img)!, imageHeaders),
    ];
  }
}
