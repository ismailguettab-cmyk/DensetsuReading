// Source model, after Tachiyomi's CatalogueSource: popular, search with filters,
// details, chapter list and page list. Each site implements this contract in Dart.

import 'dart:math';

enum MangaStatus { unknown, ongoing, completed, hiatus, cancelled }

class SourceManga {
  SourceManga({
    required this.sourceId,
    required this.url,
    required this.title,
    this.cover,
    this.description,
    this.authors = const [],
    this.genres = const [],
    this.status = MangaStatus.unknown,
    this.anilistId,
    this.altTitles = const [],
  });

  final String sourceId;
  final String url; // identifier inside the source (id or path)
  final String title;
  final String? cover;
  final String? description;
  final List<String> authors;
  final List<String> genres;
  final MangaStatus status;
  final int? anilistId;
  final List<String> altTitles;

  SourceManga copyWith({String? cover, String? description, List<String>? authors, List<String>? genres, MangaStatus? status, int? anilistId, List<String>? altTitles}) =>
      SourceManga(
        sourceId: sourceId,
        url: url,
        title: title,
        cover: cover ?? this.cover,
        description: description ?? this.description,
        authors: authors ?? this.authors,
        genres: genres ?? this.genres,
        status: status ?? this.status,
        anilistId: anilistId ?? this.anilistId,
        altTitles: altTitles ?? this.altTitles,
      );
}

class Chapter {
  Chapter({required this.url, required this.name, this.number, this.volume, this.date, this.scanlator, this.title});

  final String url;
  final String name;
  final double? number;
  final String? volume;
  final DateTime? date;
  final String? scanlator;
  final String? title;
}

class PageImage {
  const PageImage(this.url, [this.headers = const {}, this.fallback]);
  final String url;
  final Map<String, String> headers;

  /// Second address to try when the first one fails (e.g. MangaDex origin server).
  final String? fallback;
}

class MangaList {
  const MangaList(this.items, {this.hasNext = false});
  final List<SourceManga> items;
  final bool hasNext;
}

class FilterOption {
  const FilterOption(this.value, this.fr, [String? en]) : en = en ?? fr;
  final String value, fr, en;
  String label(bool english) => english ? en : fr;
}

enum FilterKind { single, multi }

class SourceFilter {
  const SourceFilter({required this.key, required this.fr, required this.en, required this.kind, required this.options});
  final String key, fr, en;
  final FilterKind kind;
  final List<FilterOption> options;
  String label(bool english) => english ? en : fr;
}

/// Selected filter values: `single` filters map to a String, `multi` to a Set<String>.
typedef FilterValues = Map<String, Object>;

abstract class MangaSource {
  String get id;
  String get name;
  String get lang; // ISO code shown to the user
  String get baseUrl;
  int get popularity; // 0–100, used to sort the Sources tab
  String get iconUrl => 'https://www.google.com/s2/favicons?domain=${Uri.parse(baseUrl).host}&sz=128';

  /// Whether a text query and filters can be combined in one search.
  bool get filtersWithQuery => true;
  List<SourceFilter> get filters => const [];
  Map<String, String> get imageHeaders => const {};

  Future<MangaList> popular(int page);
  Future<MangaList> search(String query, int page, FilterValues filters);
  Future<SourceManga> details(SourceManga manga);
  Future<List<Chapter>> chapters(SourceManga manga);
  Future<List<PageImage>> pages(Chapter chapter);
}

const statusFilter = SourceFilter(
  key: 'status',
  fr: 'Statut',
  en: 'Status',
  kind: FilterKind.single,
  options: [
    FilterOption('', 'Tous', 'All'),
    FilterOption('ongoing', 'En cours', 'Ongoing'),
    FilterOption('completed', 'Terminé', 'Completed'),
  ],
);

double? parseChapterNumber(String text) {
  final m = RegExp(r'(\d+(?:[.,]\d+)?)').allMatches(text).toList();
  if (m.isEmpty) return null;
  return double.tryParse(m.last.group(1)!.replaceAll(',', '.'));
}

String _norm(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9À-ɏ぀-ヿ一-鿿]+'), ' ').trim();

/// Words sites add to a title for a given release, not part of the name itself.
final _editionWords = RegExp(
  r'\b(edition|édition|deluxe|perfect|ultimate|kanzenban|couleurs?|colou?r(ed)?|full color|integrale|intégrale|'
  r'remaster(ed)?|originale?|nouvelle|new|vf|vostfr|fr|raw|part|partie|tome|volume|vol)\b',
);

/// A title stripped of brackets, edition markers and part numbers: "Monster – Edition Deluxe"
/// and "JoJo's Bizarre Adventure: Part 7–Steel Ball Run" compare by their core name.
String coreTitle(String s) => _norm(
      s
          .toLowerCase()
          .replaceAll(RegExp(r'\([^)]*\)|\[[^\]]*\]'), ' ')
          .replaceAll(_editionWords, ' ')
          .replaceAll(RegExp(r'\b\d+\b'), ' '),
    ).replaceAll(RegExp(r'\s+'), ' ');

double _overlap(String na, String nb) {
  if (na.isEmpty || nb.isEmpty) return 0;
  if (na == nb) return 1;
  final ta = na.split(' ').toSet(), tb = nb.split(' ').toSet();
  final jaccard = ta.intersection(tb).length / ta.union(tb).length;
  final contains = (na.contains(nb) || nb.contains(na)) ? 0.15 : 0;
  return (jaccard + contains).clamp(0, 0.99);
}

/// Title similarity in [0, 1] — token overlap with a bonus for exact matches, on the raw
/// titles and on their core names (whichever is closer).
double titleSimilarity(String a, String b) => max(_overlap(_norm(a), _norm(b)), _overlap(coreTitle(a), coreTitle(b)));

/// What to type in a source's search box to find a manga known by [titles]: the titles as
/// they are, then their core names and the part after a colon or dash (sites often file
/// "JoJo no Kimyou na Bouken: Steel Ball Run" as just "… Steel Ball Run"). At most [limit].
List<String> titleQueries(List<String> titles, {int limit = 5}) {
  final out = <String>{};
  void add(String s) {
    final t = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (t.length >= 2) out.add(t);
  }

  for (final t in titles.take(2)) {
    add(t);
  }
  for (final t in titles) {
    final plain = t.replaceAll(RegExp(r'\([^)]*\)|\[[^\]]*\]'), ' ');
    add(plain);
    final parts = plain.split(RegExp(r'\s*[:：–—]\s*|\s+-\s+'));
    if (parts.length > 1) {
      for (final p in parts.reversed) {
        final cleaned = p.replaceAll(RegExp(r'\bpart\s*\d+\b', caseSensitive: false), ' ');
        if (cleaned.trim().split(' ').length >= 2 || cleaned.trim().length >= 6) add(cleaned);
      }
    }
  }
  return out.take(limit).toList();
}
