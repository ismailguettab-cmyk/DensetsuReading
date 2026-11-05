import 'dart:convert';

import 'package:http/http.dart' as http;

class AniTag {
  const AniTag(this.name, this.rank);
  final String name;
  final int rank;
}

class AniMedia {
  AniMedia({
    required this.id,
    required this.title,
    this.english,
    this.romaji,
    this.native,
    this.synonyms = const [],
    this.cover,
    this.coverColor,
    this.banner,
    this.description,
    this.genres = const [],
    this.tags = const [],
    this.meanScore,
    this.popularity,
    this.chapters,
    this.volumes,
    this.year,
    this.status,
    this.format,
    this.country,
    this.isAdult = false,
    this.authors = const [],
  });

  final int id;
  final String title;
  final String? english, romaji, native;
  final List<String> synonyms;
  final String? cover, coverColor, banner, description;
  final List<String> genres;
  final List<AniTag> tags;
  final int? meanScore, popularity, chapters, volumes, year;
  final String? status, format, country;
  final bool isAdult;
  final List<String> authors;

  /// Every name the manga might be listed under on a source, best first.
  List<String> get searchTitles => {
        if (english != null) english!,
        if (romaji != null) romaji!,
        title,
        ...synonyms.where((s) => RegExp(r'^[\x00-\x7F]+$').hasMatch(s)),
      }.where((s) => s.trim().isNotEmpty).toList();

  factory AniMedia.fromJson(Map<String, dynamic> j) {
    final t = (j['title'] as Map?) ?? const {};
    final cover = (j['coverImage'] as Map?) ?? const {};
    final staff = ((j['staff'] as Map?)?['edges'] as List?) ?? const [];
    return AniMedia(
      id: j['id'] as int,
      title: (t['userPreferred'] ?? t['romaji'] ?? t['english'] ?? '?') as String,
      english: t['english'] as String?,
      romaji: t['romaji'] as String?,
      native: t['native'] as String?,
      synonyms: ((j['synonyms'] as List?) ?? const []).cast<String>(),
      cover: (cover['extraLarge'] ?? cover['large']) as String?,
      coverColor: cover['color'] as String?,
      banner: j['bannerImage'] as String?,
      description: _cleanDescription(j['description'] as String?),
      genres: ((j['genres'] as List?) ?? const []).cast<String>(),
      tags: ((j['tags'] as List?) ?? const [])
          .where((tag) => tag['isMediaSpoiler'] != true)
          .map((tag) => AniTag(tag['name'] as String, (tag['rank'] as int?) ?? 50))
          .toList(),
      meanScore: j['meanScore'] as int?,
      popularity: j['popularity'] as int?,
      chapters: j['chapters'] as int?,
      volumes: j['volumes'] as int?,
      year: (j['startDate'] as Map?)?['year'] as int?,
      status: j['status'] as String?,
      format: j['format'] as String?,
      country: j['countryOfOrigin'] as String?,
      isAdult: j['isAdult'] as bool? ?? false,
      authors: staff
          .where((e) => (e['role'] as String? ?? '').contains('Story') || (e['role'] as String? ?? '').contains('Art'))
          .map((e) => (e['node']?['name']?['full'] as String?) ?? '')
          .where((n) => n.isNotEmpty)
          .toSet()
          .toList(),
    );
  }

  static String? _cleanDescription(String? s) {
    if (s == null) return null;
    return s
        .replaceAll(RegExp(r'<br\s*/?>'), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&#039;', '\'')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .replaceAll(RegExp(r'\(Source:[^)]*\)'), '')
        .trim();
  }
}

class AniEntry {
  AniEntry({required this.media, required this.status, required this.score, required this.progress, required this.updated});

  final AniMedia media;
  final String status; // CURRENT, PLANNING, COMPLETED, DROPPED, PAUSED, REPEATING
  final int score; // 0–100, 0 = not scored
  final int progress;
  final DateTime updated;
}

class AniUser {
  AniUser({
    required this.id,
    required this.name,
    this.avatar,
    this.banner,
    this.count = 0,
    this.chaptersRead = 0,
    this.volumesRead = 0,
    this.meanScore = 0,
  });

  final int id;
  final String name;
  final String? avatar, banner;
  final int count, chaptersRead, volumesRead;
  final double meanScore;

  factory AniUser.fromJson(Map<String, dynamic> j) {
    final stats = (j['statistics']?['manga'] as Map?) ?? const {};
    return AniUser(
      id: j['id'] as int,
      name: j['name'] as String,
      avatar: j['avatar']?['large'] as String?,
      banner: j['bannerImage'] as String?,
      count: stats['count'] as int? ?? 0,
      chaptersRead: stats['chaptersRead'] as int? ?? 0,
      volumesRead: stats['volumesRead'] as int? ?? 0,
      meanScore: (stats['meanScore'] as num?)?.toDouble() ?? 0,
    );
  }
}

class AniListError implements Exception {
  AniListError(this.message, [this.status]);
  final String message;
  final int? status;

  @override
  String toString() => 'AniList: $message';
}

const mediaFragment = '''
fragment M on Media {
  id title { userPreferred romaji english native } synonyms
  coverImage { extraLarge large color } bannerImage genres
  tags { name rank isMediaSpoiler }
  meanScore popularity chapters volumes status format countryOfOrigin isAdult startDate { year }
}
''';

const _userFields = 'id name avatar { large } bannerImage statistics { manga { count chaptersRead volumesRead meanScore } }';

/// AniList GraphQL API. Rate limit is tight (30 requests/min), so callers batch
/// with aliases and this client waits out a 429 once before giving up.
class AniList {
  AniList([this.token]);

  static const endpoint = 'https://graphql.anilist.co';
  static const redirectUri = 'http://localhost:5173/auth';
  final String? token;

  static String authorizeUrl(String clientId) =>
      'https://anilist.co/api/v2/oauth/authorize?client_id=$clientId&response_type=token';

  Future<Map<String, dynamic>> query(String query, [Map<String, dynamic> variables = const {}]) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      final res = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'query': query, 'variables': variables}),
      );
      if (res.statusCode == 429 && attempt == 0) {
        final wait = int.tryParse(res.headers['retry-after'] ?? '') ?? 20;
        await Future<void>.delayed(Duration(seconds: wait.clamp(1, 60)));
        continue;
      }
      final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final errors = body['errors'] as List?;
      if (res.statusCode >= 400 || (errors != null && errors.isNotEmpty && body['data'] == null)) {
        final msg = errors?.isNotEmpty == true ? errors!.first['message'] as String? : null;
        throw AniListError(msg ?? 'HTTP ${res.statusCode}', res.statusCode);
      }
      return (body['data'] as Map<String, dynamic>?) ?? const {};
    }
    throw AniListError('rate limited', 429);
  }

  Future<AniUser> viewer() async => AniUser.fromJson((await query('query { Viewer { $_userFields } }'))['Viewer']);

  Future<AniUser?> userByName(String name) async {
    try {
      final data = await query(r'query($n: String) { User(name: $n) { ' + _userFields + ' } }', {'n': name});
      final u = data['User'];
      return u == null ? null : AniUser.fromJson(u as Map<String, dynamic>);
    } on AniListError catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  Future<List<AniEntry>> mangaList(int userId) async {
    final data = await query(
      r'query($id: Int) { MediaListCollection(userId: $id, type: MANGA) { lists { entries { status score(format: POINT_100) progress updatedAt media { ...M } } } } }' +
          mediaFragment,
      {'id': userId},
    );
    final lists = (data['MediaListCollection']?['lists'] as List?) ?? const [];
    final seen = <int>{};
    final out = <AniEntry>[];
    for (final l in lists) {
      for (final e in (l['entries'] as List? ?? const [])) {
        final media = AniMedia.fromJson(e['media'] as Map<String, dynamic>);
        if (!seen.add(media.id)) continue;
        out.add(AniEntry(
          media: media,
          status: e['status'] as String,
          score: (e['score'] as num?)?.round() ?? 0,
          progress: e['progress'] as int? ?? 0,
          updated: DateTime.fromMillisecondsSinceEpoch(((e['updatedAt'] as int?) ?? 0) * 1000),
        ));
      }
    }
    out.sort((a, b) => b.updated.compareTo(a.updated));
    return out;
  }

  Future<AniMedia> media(int id) async {
    final data = await query(
      r'query($id: Int) { Media(id: $id) { ...M description(asHtml: false) staff(perPage: 4, sort: RELEVANCE) { edges { role node { name { full } } } } } }' +
          mediaFragment,
      {'id': id},
    );
    return AniMedia.fromJson(data['Media'] as Map<String, dynamic>);
  }

  Future<List<AniMedia>> searchManga(String q, {int perPage = 8}) async {
    final data = await query(
      r'query($q: String, $n: Int) { Page(perPage: $n) { media(search: $q, type: MANGA, format_not: NOVEL, sort: SEARCH_MATCH) { ...M } } }' +
          mediaFragment,
      {'q': q, 'n': perPage},
    );
    return ((data['Page']?['media'] as List?) ?? const [])
        .map((m) => AniMedia.fromJson(m as Map<String, dynamic>))
        .toList();
  }

  /// Main character of a manga (name and picture), for the home page portrait.
  Future<(String, String)?> mainCharacter(int mediaId) async {
    final data = await query(
      r'query($id: Int) { Media(id: $id) { characters(role: MAIN, perPage: 1, sort: FAVOURITES_DESC) { nodes { name { full } image { large } } } } }',
      {'id': mediaId},
    );
    final nodes = (data['Media']?['characters']?['nodes'] as List?) ?? const [];
    if (nodes.isEmpty) return null;
    final image = nodes.first['image']?['large'] as String?;
    return image == null ? null : (nodes.first['name']?['full'] as String? ?? '', image);
  }

  Future<void> saveEntry(int mediaId, {String? status, int? progress}) async {
    await query(
      r'mutation($id: Int, $s: MediaListStatus, $p: Int) { SaveMediaListEntry(mediaId: $id, status: $s, progress: $p) { id } }',
      {'id': mediaId, 'p': progress, 's': status},
    );
  }
}
