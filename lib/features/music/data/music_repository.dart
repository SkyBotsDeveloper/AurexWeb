import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/music_models.dart';

final musicRepositoryProvider = Provider<MusicRepository>(
  (ref) => MusicRepository(ref.watch(apiClientProvider)),
);

class MusicRepository {
  MusicRepository(this._dio);

  final Dio _dio;

  static const Map<String, String> _homeKeyMap = {
    'new_trending': 'newTrending',
    'charts': 'charts',
    'new_albums': 'newAlbums',
    'top_playlists': 'topPlaylists',
    'radio': 'radio',
    'artist_recos': 'artistRecommendations',
    'city_mod': 'cityArtists',
    'top_shows': 'topShows',
    'promo:vx:data:68': 'promos',
    'promo:vx:data:76': 'genres',
    'promo:vx:data:107': 'channels',
    'promo:vx:data:185': 'moods',
  };

  Future<List<HomeSection>> fetchHomeSections() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/home');
    final data = readMap(response.data?['data']);
    final modules = readMapList(data['modules']);
    final sections = <HomeSection>[];

    for (final module in modules) {
      final key = readString(module['key']);
      final dataKey = _homeKeyMap[key];
      if (dataKey == null) {
        continue;
      }
      final rawItems = _extractHomeItems(
        data,
        moduleKey: key,
        dataKey: dataKey,
      );
      if (rawItems.isEmpty) {
        continue;
      }
      sections.add(
        HomeSection(
          key: key ?? dataKey,
          title: readString(module['title']) ?? 'Discover',
          subtitle: readString(module['subtitle']),
          items: rawItems.map(MediaSummary.fromJson).toList(),
          featured: readBool(module['featured']),
        ),
      );
    }

    return sections;
  }

  List<Map<String, dynamic>> _extractHomeItems(
    Map<String, dynamic> data, {
    required String? moduleKey,
    required String dataKey,
  }) {
    final directItems = readMapList(data[dataKey]);
    if (directItems.isEmpty) {
      return const [];
    }

    final hasNestedResults = directItems.any(
      (item) => readMapList(item['results']).isNotEmpty,
    );
    if (!hasNestedResults) {
      return directItems;
    }

    if (moduleKey != null) {
      for (final item in directItems) {
        final candidateKey =
            readString(item['key']) ?? readString(item['source']);
        if (candidateKey == moduleKey) {
          return readMapList(item['results']);
        }
      }
    }

    return directItems
        .expand((item) => readMapList(item['results']))
        .toList(growable: false);
  }

  Future<List<HomeSection>> fetchTrendingSections() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/trending');
    final data = readMap(response.data?['data']);
    return [
      HomeSection(
        key: 'trending_songs',
        title: 'Trending Songs',
        subtitle: 'The tracks moving fastest right now',
        items: readMapList(data['songs']).map(MediaSummary.fromJson).toList(),
        featured: true,
      ),
      HomeSection(
        key: 'trending_albums',
        title: 'Hot Albums',
        subtitle: 'Fresh album momentum',
        items: readMapList(data['albums']).map(MediaSummary.fromJson).toList(),
        featured: false,
      ),
      HomeSection(
        key: 'trending_artists',
        title: 'Popular Artists',
        subtitle: 'Artists listeners are gravitating to',
        items: readMapList(data['artists']).map(MediaSummary.fromJson).toList(),
        featured: false,
      ),
      HomeSection(
        key: 'trending_playlists',
        title: 'Playlist Heat',
        subtitle: 'Editorial and fan favorites',
        items: readMapList(
          data['playlists'],
        ).map(MediaSummary.fromJson).toList(),
        featured: false,
      ),
    ].where((section) => section.items.isNotEmpty).toList();
  }

  Future<SearchResults> searchAll(String query) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/search',
      queryParameters: {'query': query},
    );
    final data = readMap(response.data?['data']);
    return SearchResults(
      topQuery: readMapList(
        readMap(data['topQuery'])['results'],
      ).map(MediaSummary.fromJson).toList(),
      songs: readMapList(
        readMap(data['songs'])['results'],
      ).map(MediaSummary.fromJson).toList(),
      albums: readMapList(
        readMap(data['albums'])['results'],
      ).map(MediaSummary.fromJson).toList(),
      artists: readMapList(
        readMap(data['artists'])['results'],
      ).map(MediaSummary.fromJson).toList(),
      playlists: readMapList(
        readMap(data['playlists'])['results'],
      ).map(MediaSummary.fromJson).toList(),
    );
  }

  Future<Track> fetchSong(String id) async {
    final response = await _dio.get<Map<String, dynamic>>('/api/songs/$id');
    final payload = response.data?['data'];
    final trackJson = payload is List
        ? readMap(payload.isEmpty ? null : payload.first)
        : readMap(payload);
    return Track.fromJson(trackJson);
  }

  Future<CollectionDetail> fetchAlbum(String id) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/albums',
      queryParameters: {'id': id},
    );
    return CollectionDetail.fromJson(readMap(response.data?['data']));
  }

  Future<CollectionDetail> fetchPlaylist(String id) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/playlists',
      queryParameters: {'id': id},
    );
    return CollectionDetail.fromJson(readMap(response.data?['data']));
  }

  Future<ArtistDetail> fetchArtist(String id) async {
    final response = await _dio.get<Map<String, dynamic>>('/api/artists/$id');
    return ArtistDetail.fromJson(readMap(response.data?['data']));
  }

  Future<LyricsData> fetchLyrics(String id) async {
    final response = await _dio.get<Map<String, dynamic>>('/api/lyrics/$id');
    return LyricsData.fromJson(readMap(response.data?['data']));
  }

  Future<SyncedLyricsData?> fetchSyncedLyrics(String id) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/lyrics/$id/sync',
      );
      return SyncedLyricsData.fromJson(readMap(response.data?['data']));
    } on DioException {
      return null;
    }
  }

  Future<LyricsBundle> fetchBestLyrics(Track track) async {
    final lyricsId = track.lyricsId ?? track.id;

    SyncedLyricsData? synced;
    LyricsData? plain;

    try {
      synced = await fetchSyncedLyrics(lyricsId);
    } on DioException {
      synced = null;
    }

    try {
      final candidate = await fetchLyrics(lyricsId);
      if (_hasPlainLyrics(candidate)) {
        plain = candidate;
      }
    } on DioException {
      plain = null;
    }

    var usedFallback = false;
    if (!_hasSyncedLyrics(synced) || plain == null) {
      final fallback = await _fetchFallbackLyrics(track);
      if (fallback != null) {
        synced ??= fallback.synced;
        plain ??= fallback.plain;
        usedFallback = fallback.hasAny;
      }
    }

    return LyricsBundle(
      synced: _hasSyncedLyrics(synced) ? synced : null,
      plain: plain,
      sourceLabel: usedFallback ? 'LRCLIB Fallback' : 'Current Source',
      usedFallback: usedFallback,
    );
  }

  Future<LyricsBundle?> _fetchFallbackLyrics(Track track) async {
    for (final query in _fallbackSearchQueries(track)) {
      try {
        final response = await _dio.get<dynamic>(
          'https://lrclib.net/api/search',
          queryParameters: query,
        );
        final candidates = readMapList(response.data);
        final bestCandidate = _pickBestFallbackCandidate(candidates, track);
        if (bestCandidate == null) {
          continue;
        }
        final bundle = _lyricsBundleFromFallback(bestCandidate);
        if (bundle.hasAny) {
          return bundle;
        }
      } on DioException catch (error) {
        if (kDebugMode) {
          debugPrint('LRCLIB lyrics fallback failed: ${error.message}');
        }
      }
    }
    return null;
  }

  List<Map<String, dynamic>> _fallbackSearchQueries(Track track) {
    final primaryArtist = track.artists.isNotEmpty
        ? track.artists.first.name
        : track.artistNames;
    final fullTitle = track.title.trim();
    final shortTitle = fullTitle.split(RegExp(r'\s*[\(\[\-]')).first.trim();

    final queries = <Map<String, dynamic>>[
      {
        'track_name': fullTitle,
        'artist_name': primaryArtist,
        if ((track.albumName ?? '').isNotEmpty) 'album_name': track.albumName,
      },
    ];

    if (shortTitle.isNotEmpty &&
        shortTitle.toLowerCase() != fullTitle.toLowerCase()) {
      queries.add({
        'track_name': shortTitle,
        'artist_name': primaryArtist,
        if ((track.albumName ?? '').isNotEmpty) 'album_name': track.albumName,
      });
    }

    return queries;
  }

  Map<String, dynamic>? _pickBestFallbackCandidate(
    List<Map<String, dynamic>> candidates,
    Track track,
  ) {
    if (candidates.isEmpty) {
      return null;
    }

    final normalizedTitle = _normalizeLyricsKey(track.title);
    final normalizedAlbum = _normalizeLyricsKey(track.albumName ?? '');
    final normalizedArtist = _normalizeLyricsKey(
      track.artists.isNotEmpty ? track.artists.first.name : track.artistNames,
    );
    final targetDuration = track.duration?.inSeconds ?? 0;

    Map<String, dynamic>? bestCandidate;
    var bestScore = -1 << 20;

    for (final candidate in candidates) {
      if (readBool(candidate['instrumental'])) {
        continue;
      }

      final candidateTitle = _normalizeLyricsKey(
        readString(candidate['trackName']) ??
            readString(candidate['name']) ??
            '',
      );
      final candidateArtist = _normalizeLyricsKey(
        readString(candidate['artistName']) ?? '',
      );
      final candidateAlbum = _normalizeLyricsKey(
        readString(candidate['albumName']) ?? '',
      );
      final candidateDuration =
          readInt(candidate['duration']) ??
          (candidate['duration'] is num
              ? (candidate['duration'] as num).round()
              : 0);

      var score = 0;
      if (candidateTitle == normalizedTitle) {
        score += 120;
      } else if (candidateTitle.contains(normalizedTitle) ||
          normalizedTitle.contains(candidateTitle)) {
        score += 80;
      }

      if (candidateArtist.contains(normalizedArtist) ||
          normalizedArtist.contains(candidateArtist)) {
        score += 60;
      }

      if (normalizedAlbum.isNotEmpty &&
          (candidateAlbum.contains(normalizedAlbum) ||
              normalizedAlbum.contains(candidateAlbum))) {
        score += 30;
      }

      if (targetDuration > 0 && candidateDuration > 0) {
        score -= (candidateDuration - targetDuration).abs();
      }

      if (score > bestScore) {
        bestScore = score;
        bestCandidate = candidate;
      }
    }

    return bestCandidate;
  }

  LyricsBundle _lyricsBundleFromFallback(Map<String, dynamic> candidate) {
    final id = readString(candidate['id']) ?? 'lrclib';
    final trackName =
        readString(candidate['trackName']) ??
        readString(candidate['name']) ??
        'Lyrics';
    final plainText = readString(candidate['plainLyrics']) ?? '';
    final syncedText = readString(candidate['syncedLyrics']) ?? '';
    final durationSeconds =
        readInt(candidate['duration']) ??
        (candidate['duration'] is num
            ? (candidate['duration'] as num).round()
            : 0);

    final plain = plainText.trim().isEmpty
        ? null
        : LyricsData(
            id: '$id-plain',
            lyrics: plainText,
            lines: plainText
                .split('\n')
                .map((line) => line.trimRight())
                .where((line) => line.trim().isNotEmpty)
                .toList(growable: false),
            snippet: trackName,
            copyright: 'Source: LRCLIB',
          );

    final syncedLines = syncedText.trim().isEmpty
        ? const <SyncedLyricLine>[]
        : _parseSyncedLyrics(
            syncedText,
            durationSeconds > 0 ? durationSeconds * 1000 : null,
          );

    final synced = syncedLines.isEmpty
        ? null
        : SyncedLyricsData(
            id: '$id-sync',
            hasSync: true,
            duration: durationSeconds > 0 ? durationSeconds * 1000 : null,
            lines: syncedLines,
            source: 'LRCLIB',
          );

    return LyricsBundle(
      synced: synced,
      plain: plain,
      sourceLabel: 'LRCLIB Fallback',
      usedFallback: true,
    );
  }

  List<SyncedLyricLine> _parseSyncedLyrics(String raw, int? durationMs) {
    final timestampPattern = RegExp(r'\[(\d{1,2}):(\d{2})(?:[.:](\d{1,3}))?\]');
    final entries = <({int startMs, String text})>[];

    for (final line in raw.split('\n')) {
      final matches = timestampPattern.allMatches(line).toList(growable: false);
      if (matches.isEmpty) {
        continue;
      }

      final text = line.replaceAll(timestampPattern, '').trim();
      if (text.isEmpty) {
        continue;
      }

      for (final match in matches) {
        final minutes = int.tryParse(match.group(1) ?? '') ?? 0;
        final seconds = int.tryParse(match.group(2) ?? '') ?? 0;
        final fractionRaw = match.group(3) ?? '0';
        final fraction = int.tryParse(fractionRaw) ?? 0;
        final milliseconds = switch (fractionRaw.length) {
          0 => 0,
          1 => fraction * 100,
          2 => fraction * 10,
          _ => fraction,
        };
        final startMs = (minutes * 60 * 1000) + (seconds * 1000) + milliseconds;
        entries.add((startMs: startMs, text: text));
      }
    }

    entries.sort((a, b) => a.startMs.compareTo(b.startMs));
    if (entries.isEmpty) {
      return const [];
    }

    final lines = <SyncedLyricLine>[];
    for (var index = 0; index < entries.length; index++) {
      final current = entries[index];
      final next = index + 1 < entries.length ? entries[index + 1] : null;
      final endMs = next != null
          ? next.startMs
          : durationMs ?? (current.startMs + 4000);
      lines.add(
        SyncedLyricLine(
          text: current.text,
          startTimeMs: current.startMs,
          endTimeMs: endMs,
        ),
      );
    }
    return lines;
  }

  bool _hasSyncedLyrics(SyncedLyricsData? data) =>
      data != null && data.lines.isNotEmpty;

  bool _hasPlainLyrics(LyricsData? data) =>
      data != null && (data.lyrics.trim().isNotEmpty || data.lines.isNotEmpty);

  String _normalizeLyricsKey(String value) {
    final normalized = value.toLowerCase();
    return normalized.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  }
}
