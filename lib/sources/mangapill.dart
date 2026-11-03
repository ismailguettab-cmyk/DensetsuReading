import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;

import '../core/net.dart';
import 'source.dart';

/// mangapill.com (English). HTML pages; images require the site as Referer.
class MangaPill extends MangaSource {
  @override
  String get id => 'mangapill';
  @override
  String get name => 'MangaPill';
  @override
  String get lang => 'en';
  @override
  String get baseUrl => 'https://mangapill.com';
  @override
  int get popularity => 82;
  @override
  Map<String, String> get imageHeaders => const {'Referer': 'https://mangapill.com/'};

  static const _genres = [
    'Action', 'Adventure', 'Cars', 'Comedy', 'Dementia', 'Demons', 'Drama', 'Ecchi', 'Fantasy', 'Game',
    'Harem', 'Historical', 'Horror', 'Josei', 'Kids', 'Magic', 'Martial Arts', 'Mecha', 'Military', 'Music',
    'Mystery', 'Parody', 'Police', 'Psychological', 'Romance', 'Samurai', 'School', 'Sci-Fi', 'Seinen', 'Shoujo',
    'Shoujo Ai', 'Shounen', 'Shounen Ai', 'Slice of Life', 'Space', 'Sports', 'Super Power', 'Supernatural',
    'Thriller', 'Tragedy', 'Vampire',
  ];

  @override
  List<SourceFilter> get filters => [
        SourceFilter(
          key: 'status',
          fr: 'Statut',
          en: 'Status',
          kind: FilterKind.single,
          options: [
            FilterOption('', 'Tous', 'All'),
            FilterOption('publishing', 'En cours', 'Ongoing'),
            FilterOption('finished', 'Terminé', 'Completed'),
            FilterOption('on hiatus', 'En pause', 'On hiatus'),
          ],
        ),
        SourceFilter(
          key: 'type',
          fr: 'Type',
          en: 'Type',
          kind: FilterKind.single,
          options: [
            FilterOption('', 'Tous', 'All'),
            FilterOption('manga', 'Manga'),
            FilterOption('manhwa', 'Manhwa'),
            FilterOption('manhua', 'Manhua'),
            FilterOption('one-shot', 'One-shot'),
          ],
        ),
        SourceFilter(
          key: 'genre',
          fr: 'Catégories',
          en: 'Categories',
          kind: FilterKind.multi,
          options: [for (final g in _genres) FilterOption(g, g)],
        ),
      ];

  List<SourceManga> _cards(Document doc) {
    final out = <SourceManga>[];
    final seen = <String>{};
    for (final a in doc.querySelectorAll('a[href^="/manga/"]')) {
      final href = a.attributes['href']!;
      final img = a.querySelector('img');
      if (img == null || !seen.add(href)) continue;
      final title = a.parent?.querySelector('div.line-clamp-2, .font-black')?.text.trim();
      out.add(SourceManga(
        sourceId: id,
        url: href,
        title: (title == null || title.isEmpty) ? (img.attributes['alt'] ?? '?') : title,
        cover: img.attributes['data-src'] ?? img.attributes['src'],
      ));
    }
    return out;
  }

  @override
  Future<MangaList> popular(int page) => search('', page, const {});

  @override
  Future<MangaList> search(String query, int page, FilterValues filters) async {
    final params = <String>[
      'q=${Uri.encodeQueryComponent(query.trim())}',
      'type=${Uri.encodeQueryComponent(filters['type'] as String? ?? '')}',
      'status=${Uri.encodeQueryComponent(filters['status'] as String? ?? '')}',
      for (final g in (filters['genre'] as Set<String>? ?? const {})) 'genre=${Uri.encodeQueryComponent(g)}',
      'page=$page',
    ];
    final doc = html.parse(await Net.getText('$baseUrl/search?${params.join('&')}'));
    final items = _cards(doc);
    return MangaList(items, hasNext: items.length >= 50 || doc.querySelector('a[href*="page=${page + 1}"]') != null);
  }

  @override
  Future<SourceManga> details(SourceManga manga) async {
    final doc = html.parse(await Net.getText('$baseUrl${manga.url}'));
    String? field(String label) {
      for (final l in doc.querySelectorAll('label')) {
        if (l.text.trim().toLowerCase() == label) return l.nextElementSibling?.text.trim();
      }
      return null;
    }

    final status = field('status')?.toLowerCase() ?? '';
    return manga.copyWith(
      cover: doc.querySelector('img[data-src*="/i/"]')?.attributes['data-src'] ?? manga.cover,
      description: doc.querySelector('p.text--secondary, p.text-sm.text--secondary')?.text.trim(),
      genres: [for (final a in doc.querySelectorAll('a[href^="/search?genre="]')) a.text.trim()],
      status: status.contains('publishing')
          ? MangaStatus.ongoing
          : status.contains('finished')
              ? MangaStatus.completed
              : status.contains('hiatus')
                  ? MangaStatus.hiatus
                  : MangaStatus.unknown,
    );
  }

  @override
  Future<List<Chapter>> chapters(SourceManga manga) async {
    final doc = html.parse(await Net.getText('$baseUrl${manga.url}'));
    final out = <Chapter>[];
    for (final a in doc.querySelectorAll('#chapters a[href^="/chapters/"], a[href^="/chapters/"]')) {
      final name = a.text.trim();
      if (out.any((c) => c.url == a.attributes['href'])) continue;
      out.add(Chapter(url: a.attributes['href']!, name: name.replaceFirst('Chapter', 'Chapitre'), number: parseChapterNumber(name)));
    }
    return out.reversed.toList();
  }

  @override
  Future<List<PageImage>> pages(Chapter chapter) async {
    final doc = html.parse(await Net.getText('$baseUrl${chapter.url}'));
    return [
      for (final img in doc.querySelectorAll('img.js-page'))
        if (img.attributes['data-src'] != null) PageImage(img.attributes['data-src']!, imageHeaders),
    ];
  }
}
