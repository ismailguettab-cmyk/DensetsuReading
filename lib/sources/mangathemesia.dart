import 'dart:convert';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;

import '../core/net.dart';
import 'source.dart';

/// Engine for WordPress sites on the MangaThemesia theme (Tachiyomi's "multisrc"
/// idea: one implementation, many sites). Each site only provides its settings.
class MangaThemesia extends MangaSource {
  MangaThemesia({
    required this.id,
    required this.name,
    required this.lang,
    required this.baseUrl,
    required this.popularity,
    this.catalogPath = '/manga',
    this.genres = const [],
  });

  @override
  final String id, name, lang, baseUrl;
  @override
  final int popularity;
  final String catalogPath;
  final List<FilterOption> genres;

  @override
  Map<String, String> get imageHeaders => {'Referer': '$baseUrl/'};

  @override
  List<SourceFilter> get filters => [
        statusFilter,
        const SourceFilter(
          key: 'order',
          fr: 'Trier par',
          en: 'Sort by',
          kind: FilterKind.single,
          options: [
            FilterOption('popular', 'Popularité', 'Popularity'),
            FilterOption('update', 'Mise à jour', 'Latest update'),
            FilterOption('latest', 'Ajout récent', 'Recently added'),
            FilterOption('title', 'A → Z', 'A → Z'),
          ],
        ),
        if (genres.isNotEmpty) SourceFilter(key: 'genre', fr: 'Catégories', en: 'Categories', kind: FilterKind.multi, options: genres),
      ];

  List<SourceManga> _cards(Document doc) => [
        for (final card in doc.querySelectorAll('div.bsx'))
          if (card.querySelector('a') != null)
            SourceManga(
              sourceId: id,
              url: _path(card.querySelector('a')!.attributes['href']!),
              title: (card.querySelector('a')!.attributes['title'] ?? card.querySelector('.tt')?.text ?? '?').trim(),
              cover: _img(card.querySelector('img')),
            ),
      ];

  String _path(String href) => href.startsWith(baseUrl) ? href.substring(baseUrl.length) : href;

  String? _img(Element? img) {
    if (img == null) return null;
    final src = img.attributes['data-src'] ?? img.attributes['data-lazy-src'] ?? img.attributes['src'];
    return src?.trim().split('?').first;
  }

  Future<MangaList> _list(String url) async {
    final doc = html.parse(await Net.getText(url));
    final items = _cards(doc);
    final next = doc.querySelector('a.next, a.r, .hpage a.r') != null;
    return MangaList(items, hasNext: next || items.length >= 20);
  }

  @override
  Future<MangaList> popular(int page) => _list('$baseUrl$catalogPath/?page=$page&order=popular');

  @override
  Future<MangaList> search(String query, int page, FilterValues filters) {
    final params = <String>[
      'page=$page',
      if (query.trim().isNotEmpty) 'title=${Uri.encodeQueryComponent(query.trim())}',
      'status=${filters['status'] as String? ?? ''}',
      'order=${filters['order'] as String? ?? (query.trim().isEmpty ? 'popular' : '')}',
      for (final g in (filters['genre'] as Set<String>? ?? const {})) 'genre%5B%5D=$g',
    ];
    // The catalogue's title filter returns every match on one page (the site's ?s= search
    // pages them 10 at a time, so a plain "Monster" was on page 2 and never found).
    return _list('$baseUrl$catalogPath/?${params.join('&')}');
  }

  @override
  Future<SourceManga> details(SourceManga manga) async {
    final doc = html.parse(await Net.getText('$baseUrl${manga.url}'));
    final info = <String, String>{};
    for (final row in doc.querySelectorAll('.infotable tr, .tsinfo .imptdt')) {
      final cells = row.querySelectorAll('td');
      if (cells.length == 2) {
        info[cells[0].text.trim().toLowerCase()] = cells[1].text.trim();
      } else {
        final label = row.nodes.isNotEmpty ? row.nodes.first.text?.trim().toLowerCase() ?? '' : '';
        info[label] = row.querySelector('i, a')?.text.trim() ?? '';
      }
    }
    final status = (info['statut'] ?? info['status'] ?? '').toLowerCase();
    return manga.copyWith(
      cover: _img(doc.querySelector('.thumb img')) ?? manga.cover,
      description: doc.querySelector('[itemprop="description"]')?.text.trim(),
      authors: [if ((info['auteur'] ?? info['author'] ?? '').isNotEmpty) (info['auteur'] ?? info['author'])!],
      genres: [for (final a in doc.querySelectorAll('.mgen a, .seriestugenre a, a[rel="tag"][href*="/genres/"]')) a.text.trim()].toSet().toList(),
      status: status.contains('cours') || status.contains('ongoing')
          ? MangaStatus.ongoing
          : status.contains('termin') || status.contains('complete')
              ? MangaStatus.completed
              : status.contains('pause') || status.contains('hiatus')
                  ? MangaStatus.hiatus
                  : MangaStatus.unknown,
    );
  }

  @override
  Future<List<Chapter>> chapters(SourceManga manga) async {
    final doc = html.parse(await Net.getText('$baseUrl${manga.url}'));
    final out = <Chapter>[];
    for (final li in doc.querySelectorAll('#chapterlist li, .eplister li')) {
      final a = li.querySelector('a');
      if (a == null) continue;
      final name = (li.querySelector('.chapternum')?.text ?? a.text).replaceAll(RegExp(r'\s+'), ' ').trim();
      out.add(Chapter(
        url: _path(a.attributes['href']!),
        name: name,
        number: parseChapterNumber(li.attributes['data-num'] ?? name),
        date: _date(li.querySelector('.chapterdate')?.text.trim()),
      ));
    }
    return out.reversed.toList();
  }

  @override
  Future<List<PageImage>> pages(Chapter chapter) async {
    final text = await Net.getText('$baseUrl${chapter.url}');
    // Pages are listed in a ts_reader.run({...}) call rather than in the HTML.
    final m = RegExp(r'ts_reader\.run\((\{.*?\})\);', dotAll: true).firstMatch(text);
    if (m != null) {
      final json = jsonDecode(m.group(1)!) as Map<String, dynamic>;
      final sources = json['sources'] as List? ?? const [];
      if (sources.isNotEmpty) {
        return [for (final url in (sources.first['images'] as List)) PageImage(url as String, imageHeaders)];
      }
    }
    final doc = html.parse(text);
    return [
      for (final img in doc.querySelectorAll('#readerarea img'))
        if (_img(img) != null) PageImage(_img(img)!, imageHeaders),
    ];
  }

  static const _months = {
    'janvier': 1, 'février': 2, 'fevrier': 2, 'mars': 3, 'avril': 4, 'mai': 5, 'juin': 6, 'juillet': 7,
    'août': 8, 'aout': 8, 'septembre': 9, 'octobre': 10, 'novembre': 11, 'décembre': 12, 'decembre': 12,
    'january': 1, 'february': 2, 'march': 3, 'april': 4, 'may': 5, 'june': 6, 'july': 7, 'august': 8,
    'september': 9, 'october': 10, 'november': 11, 'december': 12,
  };

  static DateTime? _date(String? s) {
    if (s == null) return null;
    final fr = RegExp(r'(\d{1,2})\s+([^\s\d]+)\s+(\d{4})').firstMatch(s);
    if (fr != null) {
      final month = _months[fr.group(2)!.toLowerCase()];
      if (month != null) return DateTime(int.parse(fr.group(3)!), month, int.parse(fr.group(1)!));
    }
    final en = RegExp(r'([A-Za-z]+)\s+(\d{1,2}),\s+(\d{4})').firstMatch(s);
    if (en != null) {
      final month = _months[en.group(1)!.toLowerCase()];
      if (month != null) return DateTime(int.parse(en.group(3)!), month, int.parse(en.group(2)!));
    }
    return null;
  }
}

const sushiScanGenres = [
  FilterOption('3', 'Action'), FilterOption('12', 'Aventure', 'Adventure'), FilterOption('13', 'Comédie', 'Comedy'),
  FilterOption('4', 'Drame', 'Drama'), FilterOption('43', 'Ecchi'), FilterOption('5', 'Fantastique', 'Fantastic'),
  FilterOption('32', 'Fantasy'), FilterOption('2455', 'Furyo'), FilterOption('24', 'Historique', 'Historical'),
  FilterOption('6', 'Horreur', 'Horror'), FilterOption('639', 'Isekai'), FilterOption('7', 'Mature'),
  FilterOption('8', 'Mystère', 'Mystery'), FilterOption('764', 'Nekketsu'), FilterOption('3251', 'Polar', 'Crime'),
  FilterOption('20', 'Psychologique', 'Psychological'), FilterOption('26', 'Romance'), FilterOption('16', 'School life'),
  FilterOption('37', 'Science-fiction', 'Sci-fi'), FilterOption('28', 'Tranche de vie', 'Slice of life'),
  FilterOption('18', 'Sport', 'Sports'), FilterOption('9', 'Surnaturel', 'Supernatural'), FilterOption('79', 'Thriller'),
  FilterOption('305', 'Tournois', 'Tournament'), FilterOption('10', 'Tragique', 'Tragedy'),
];
