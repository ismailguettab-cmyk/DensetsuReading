import '../core/net.dart';
import 'source.dart';

/// MangaDex official API. One source per translation language, like Tachiyomi.
class MangaDex extends MangaSource {
  MangaDex(this.lang, this.langName, this.popularity);

  @override
  final String lang;
  final String langName;
  @override
  final int popularity;

  static const _api = 'https://api.mangadex.org';
  static List<FilterOption>? _tags;

  @override
  String get id => 'mangadex-$lang';
  @override
  String get name => 'MangaDex';
  @override
  String get baseUrl => 'https://mangadex.org';

  static const _ratings = 'contentRating[]=safe&contentRating[]=suggestive&contentRating[]=erotica';

  @override
  List<SourceFilter> get filters => [
        statusFilter,
        const SourceFilter(
          key: 'demographic',
          fr: 'Public',
          en: 'Demographic',
          kind: FilterKind.single,
          options: [
            FilterOption('', 'Tous', 'All'),
            FilterOption('shounen', 'Shōnen'),
            FilterOption('shoujo', 'Shōjo'),
            FilterOption('seinen', 'Seinen'),
            FilterOption('josei', 'Josei'),
          ],
        ),
        SourceFilter(key: 'tags', fr: 'Catégories', en: 'Categories', kind: FilterKind.multi, options: _tags ?? const []),
        const SourceFilter(
          key: 'sort',
          fr: 'Trier par',
          en: 'Sort by',
          kind: FilterKind.single,
          options: [
            FilterOption('relevance', 'Pertinence', 'Relevance'),
            FilterOption('followedCount', 'Popularité', 'Popularity'),
            FilterOption('latestUploadedChapter', 'Dernière sortie', 'Latest upload'),
            FilterOption('rating', 'Note', 'Rating'),
          ],
        ),
      ];

  /// Genre/theme tags are fetched once so the filter sheet can list them.
  static Future<void> loadTags() async {
    if (_tags != null) return;
    final json = await Net.getJson('$_api/manga/tag');
    final tags = <FilterOption>[];
    for (final t in json['data'] as List) {
      final group = t['attributes']['group'] as String;
      if (group != 'genre' && group != 'theme') continue;
      tags.add(FilterOption(t['id'] as String, (t['attributes']['name']['en'] as String)));
    }
    tags.sort((a, b) => a.fr.compareTo(b.fr));
    _tags = tags;
  }

  Future<MangaList> _list(String query) async {
    final json = await Net.getJson('$_api/manga?$query&limit=24&includes[]=cover_art&$_ratings&availableTranslatedLanguage[]=$lang');
    final items = [for (final m in json['data'] as List) _parse(m as Map<String, dynamic>)];
    final total = json['total'] as int? ?? 0;
    final offset = json['offset'] as int? ?? 0;
    return MangaList(items, hasNext: offset + items.length < total);
  }

  @override
  Future<MangaList> popular(int page) => _list('order[followedCount]=desc&offset=${(page - 1) * 24}');

  @override
  Future<MangaList> search(String query, int page, FilterValues filters) async {
    await loadTags();
    final q = StringBuffer('offset=${(page - 1) * 24}');
    if (query.trim().isNotEmpty) q.write('&title=${Uri.encodeQueryComponent(query.trim())}');
    final status = filters['status'] as String? ?? '';
    if (status.isNotEmpty) q.write('&status[]=$status');
    final demo = filters['demographic'] as String? ?? '';
    if (demo.isNotEmpty) q.write('&publicationDemographic[]=$demo');
    for (final tag in (filters['tags'] as Set<String>? ?? const {})) {
      q.write('&includedTags[]=$tag');
    }
    var sort = filters['sort'] as String? ?? 'relevance';
    if (query.trim().isEmpty && sort == 'relevance') sort = 'followedCount';
    q.write('&order[$sort]=desc');
    return _list(q.toString());
  }

  SourceManga _parse(Map<String, dynamic> m) {
    final a = m['attributes'] as Map<String, dynamic>;
    final titles = (a['title'] as Map).cast<String, String>();
    final alt = [
      for (final t in (a['altTitles'] as List? ?? const [])) ...(t as Map).values.cast<String>(),
    ];
    final title = titles['en'] ?? titles['ja-ro'] ?? (titles.values.isNotEmpty ? titles.values.first : '?');
    String? coverFile;
    final authors = <String>[];
    for (final r in (m['relationships'] as List? ?? const [])) {
      if (r['type'] == 'cover_art') coverFile = r['attributes']?['fileName'] as String?;
      if ((r['type'] == 'author' || r['type'] == 'artist') && r['attributes'] != null) {
        authors.add(r['attributes']['name'] as String);
      }
    }
    final desc = (a['description'] as Map?)?.cast<String, String>() ?? const {};
    final description = desc[lang] ?? (lang.startsWith('fr') ? null : desc['en']);
    final links = (a['links'] as Map?)?.cast<String, dynamic>() ?? const {};
    final tags = [
      for (final t in (a['tags'] as List? ?? const [])) (t['attributes']['name']['en'] as String),
    ];
    return SourceManga(
      sourceId: id,
      url: m['id'] as String,
      title: title,
      cover: coverFile == null ? null : 'https://uploads.mangadex.org/covers/${m['id']}/$coverFile.512.jpg',
      description: description?.replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'$1').replaceAll('---', '').trim(),
      authors: authors.toSet().toList(),
      genres: tags,
      status: switch (a['status']) {
        'ongoing' => MangaStatus.ongoing,
        'completed' => MangaStatus.completed,
        'hiatus' => MangaStatus.hiatus,
        'cancelled' => MangaStatus.cancelled,
        _ => MangaStatus.unknown,
      },
      anilistId: int.tryParse('${links['al'] ?? ''}'),
      altTitles: [...titles.values, ...alt],
    );
  }

  @override
  Future<SourceManga> details(SourceManga manga) async {
    final json = await Net.getJson('$_api/manga/${manga.url}?includes[]=cover_art&includes[]=author&includes[]=artist');
    return _parse(json['data'] as Map<String, dynamic>);
  }

  /// Finds the French (or other language) synopsis for an AniList title.
  static Future<String?> descriptionFor(int anilistId, List<String> titles, String lang) async {
    for (final title in titles.take(2)) {
      final json = await Net.getJson('$_api/manga?title=${Uri.encodeQueryComponent(title)}&limit=10&$_ratings');
      for (final m in json['data'] as List) {
        final a = m['attributes'] as Map<String, dynamic>;
        if ('${(a['links'] as Map?)?['al']}' != '$anilistId') continue;
        final d = (a['description'] as Map?)?[lang] as String?;
        return d?.replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'$1').replaceAll('---', '').trim();
      }
    }
    return null;
  }

  @override
  Future<List<Chapter>> chapters(SourceManga manga) async {
    final out = <Chapter>[];
    final seen = <String>{};
    for (var offset = 0; offset < 5000; offset += 500) {
      final json = await Net.getJson(
        '$_api/manga/${manga.url}/feed?translatedLanguage[]=$lang&limit=500&offset=$offset'
        '&order[volume]=asc&order[chapter]=asc&includes[]=scanlation_group&includeExternalUrl=0&$_ratings',
      );
      final data = json['data'] as List;
      for (final c in data) {
        final a = c['attributes'] as Map<String, dynamic>;
        if ((a['pages'] as int? ?? 0) == 0) continue;
        final number = a['chapter'] as String?;
        // Several groups often translate the same chapter: keep the first.
        if (!seen.add(number ?? c['id'] as String)) continue;
        String? group;
        for (final r in (c['relationships'] as List? ?? const [])) {
          if (r['type'] == 'scanlation_group') group = r['attributes']?['name'] as String?;
        }
        final title = (a['title'] as String?)?.trim();
        out.add(Chapter(
          url: c['id'] as String,
          name: number == null ? (title?.isNotEmpty == true ? title! : 'Oneshot') : 'Chapitre $number',
          title: title?.isNotEmpty == true ? title : null,
          number: number == null ? null : double.tryParse(number),
          volume: a['volume'] as String?,
          date: DateTime.tryParse(a['publishAt'] as String? ?? ''),
          scanlator: group,
        ));
      }
      if (offset + data.length >= (json['total'] as int? ?? 0)) break;
    }
    return out;
  }

  @override
  Future<List<PageImage>> pages(Chapter chapter) async {
    final json = await Net.getJson('$_api/at-home/server/${chapter.url}');
    final base = json['baseUrl'] as String;
    final hash = json['chapter']['hash'] as String;
    return [for (final f in json['chapter']['data'] as List) PageImage('$base/data/$hash/$f', const {}, 'https://uploads.mangadex.org/data/$hash/$f')];
  }
}
