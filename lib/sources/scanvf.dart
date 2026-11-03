import 'package:html/parser.dart' as html;

import '../core/net.dart';
import 'source.dart';

/// scan-vf.net (French), built on the "My Manga Reader CMS" engine.
/// Its search only takes a title, so filters apply to browsing, not to a query.
class ScanVF extends MangaSource {
  @override
  String get id => 'scanvf';
  @override
  String get name => 'Scan-VF';
  @override
  String get lang => 'fr';
  @override
  String get baseUrl => 'https://www.scan-vf.net';
  @override
  int get popularity => 74;
  @override
  bool get filtersWithQuery => false;
  @override
  Map<String, String> get imageHeaders => const {'Referer': 'https://www.scan-vf.net/'};

  @override
  List<SourceFilter> get filters => const [
        SourceFilter(
          key: 'sort',
          fr: 'Trier par',
          en: 'Sort by',
          kind: FilterKind.single,
          options: [
            FilterOption('views', 'Popularité', 'Popularity'),
            FilterOption('name', 'Nom', 'Name'),
            FilterOption('last_release', 'Dernière sortie', 'Latest release'),
          ],
        ),
      ];

  Future<MangaList> _browse(int page, String sort) async {
    final asc = sort == 'name' ? 'true' : 'false';
    final doc = html.parse(await Net.getText('$baseUrl/filterList?page=$page&sortBy=$sort&asc=$asc'));
    final items = [
      for (final media in doc.querySelectorAll('div.media'))
        if (media.querySelector('a.chart-title') != null)
          SourceManga(
            sourceId: id,
            url: media.querySelector('a.chart-title')!.attributes['href']!.replaceFirst(baseUrl, ''),
            title: media.querySelector('a.chart-title')!.text.trim(),
            cover: media.querySelector('img')?.attributes['src']?.trim(),
          ),
    ];
    return MangaList(items, hasNext: items.length >= 20);
  }

  @override
  Future<MangaList> popular(int page) => _browse(page, 'views');

  @override
  Future<MangaList> search(String query, int page, FilterValues filters) async {
    if (query.trim().isEmpty) return _browse(page, filters['sort'] as String? ?? 'views');
    if (page > 1) return const MangaList([]);
    final json = await Net.getJson('$baseUrl/search?query=${Uri.encodeQueryComponent(query.trim())}');
    return MangaList([
      for (final s in (json['suggestions'] as List? ?? const []))
        SourceManga(
          sourceId: id,
          url: '/${s['data']}',
          title: s['value'] as String,
          cover: '$baseUrl/uploads/manga/${s['data']}/cover/cover_250x350.jpg',
        ),
    ]);
  }

  @override
  Future<SourceManga> details(SourceManga manga) async {
    final doc = html.parse(await Net.getText('$baseUrl${manga.url}'));
    final fields = <String, String>{};
    final dts = doc.querySelectorAll('dl.dl-horizontal dt');
    for (final dt in dts) {
      fields[dt.text.trim().toLowerCase()] = dt.nextElementSibling?.text.replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
    }
    final status = fields['statut']?.toLowerCase() ?? '';
    return manga.copyWith(
      cover: doc.querySelector('img.img-responsive')?.attributes['src']?.trim() ?? manga.cover,
      description: doc.querySelector('div.well p')?.text.trim(),
      authors: [if ((fields['auteur(s)'] ?? '').isNotEmpty) fields['auteur(s)']!],
      genres: (fields['catégories'] ?? '').split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
      status: status.contains('cours') ? MangaStatus.ongoing : (status.contains('termin') ? MangaStatus.completed : MangaStatus.unknown),
      altTitles: (fields['autres noms'] ?? '').split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
    );
  }

  @override
  Future<List<Chapter>> chapters(SourceManga manga) async {
    final doc = html.parse(await Net.getText('$baseUrl${manga.url}'));
    final out = <Chapter>[];
    for (final h in doc.querySelectorAll('h5.chapter-title-rtl')) {
      final a = h.querySelector('a');
      if (a == null) continue;
      final label = a.text.trim();
      final number = parseChapterNumber(label);
      final title = h.querySelector('em')?.text.trim();
      final dateText = h.parent?.querySelector('.date-chapter-title-rtl')?.text.trim();
      out.add(Chapter(
        url: a.attributes['href']!.replaceFirst(baseUrl, ''),
        name: number != null ? 'Chapitre ${_fmt(number)}' : label,
        title: (title?.isNotEmpty ?? false) ? title : null,
        number: number,
        date: _date(dateText),
      ));
    }
    return out.reversed.toList();
  }

  @override
  Future<List<PageImage>> pages(Chapter chapter) async {
    final doc = html.parse(await Net.getText('$baseUrl${chapter.url}'));
    return [
      for (final img in doc.querySelectorAll('img.img-responsive[data-src]'))
        PageImage(img.attributes['data-src']!.trim(), imageHeaders),
    ];
  }

  static String _fmt(double n) => n == n.roundToDouble() ? n.toInt().toString() : n.toString();

  static const _months = {
    'janv': 1, 'févr': 2, 'fevr': 2, 'mars': 3, 'avr': 4, 'mai': 5, 'juin': 6,
    'juil': 7, 'août': 8, 'aout': 8, 'sept': 9, 'oct': 10, 'nov': 11, 'déc': 12, 'dec': 12,
  };

  static DateTime? _date(String? s) {
    if (s == null) return null;
    final m = RegExp(r'(\d{1,2})\s+([A-Za-zéûè]+)\.?\s+(\d{4})').firstMatch(s);
    if (m == null) return null;
    final month = _months[m.group(2)!.toLowerCase()];
    if (month == null) return null;
    return DateTime(int.parse(m.group(3)!), month, int.parse(m.group(1)!));
  }
}
