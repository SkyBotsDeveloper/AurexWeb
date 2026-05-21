import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../../../core/config/app_providers.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/music_models.dart';

final aurexApiClientProvider = Provider<AurexApiClient>((ref) {
  final env = ref.watch(appEnvProvider);
  final logger = ref.watch(appLoggerProvider);
  return AurexApiClient(
    Dio(
      BaseOptions(
        baseUrl: env.aurexApiBaseUrl,
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 12),
        responseType: ResponseType.json,
      ),
    ),
    logger,
  );
});

class AurexApiClient {
  AurexApiClient(this._dio, this._logger);

  final Dio _dio;
  final Logger _logger;
  final Map<String, _AurexSearchCacheEntry> _searchCache = {};

  static const Duration _searchCacheTtl = Duration(minutes: 7);
  static const Set<int> _retryableResolveStatusCodes = {
    408,
    425,
    429,
    500,
    502,
    503,
    504,
  };

  Future<List<AurexSong>> searchAurexSongs(
    String query, {
    int limit = 10,
    CancelToken? cancelToken,
    bool forceRefresh = false,
  }) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.length < 2) {
      return const [];
    }

    final cacheKey = '${trimmedQuery.toLowerCase()}::$limit';
    final cached = _searchCache[cacheKey];
    if (!forceRefresh &&
        cached != null &&
        DateTime.now().difference(cached.createdAt) < _searchCacheTtl) {
      return cached.results;
    }

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/search',
        queryParameters: {'q': trimmedQuery, 'limit': limit},
        cancelToken: cancelToken,
      );

      final payload = readMap(response.data);
      if (!readBool(payload['success'])) {
        throw const AurexApiException(
          'Online search is temporarily unavailable.',
        );
      }

      final results = readMapList(payload['results'])
          .map(_songFromJson)
          .where(
            (song) =>
                song.videoId.trim().isNotEmpty && song.title.trim().isNotEmpty,
          )
          .toList(growable: false);

      _searchCache[cacheKey] = _AurexSearchCacheEntry(
        createdAt: DateTime.now(),
        results: results,
      );
      return results;
    } on DioException catch (error, stackTrace) {
      if (CancelToken.isCancel(error)) {
        rethrow;
      }
      if (kDebugMode) {
        _logger.e(
          'Aurex online search failed',
          error: error.message,
          stackTrace: stackTrace,
        );
      }
      throw const AurexApiException(
        'Online search is temporarily unavailable.',
      );
    }
  }

  Future<AurexResolvedAudio> resolveAurexSong(
    String videoId, {
    String format = 'mp3',
    CancelToken? cancelToken,
  }) async {
    final cleanVideoId = videoId.trim();
    if (cleanVideoId.isEmpty) {
      throw const AurexApiException(
        'Could not load this song. Please try another result.',
      );
    }

    try {
      final response = await _getResolveWithRetry(
        '/api/resolve',
        queryParameters: {'videoId': cleanVideoId, 'format': format},
        cancelToken: cancelToken,
      );
      final payload = readMap(response.data);
      if (!readBool(payload['success'])) {
        throw const AurexApiException(
          'Could not load this song. Please try another result.',
        );
      }
      final audio = readMap(payload['audio']);
      return AurexResolvedAudio(
        videoId: readString(payload['videoId']) ?? cleanVideoId,
        youtubeUrl: readString(payload['youtubeUrl']),
        streamLink: readString(audio['streamLink']),
        directLink: readString(audio['directLink']),
      );
    } on DioException catch (error, stackTrace) {
      if (CancelToken.isCancel(error)) {
        rethrow;
      }
      if (kDebugMode) {
        _logger.e(
          'Aurex song resolve failed',
          error: error.message,
          stackTrace: stackTrace,
        );
      }
      throw const AurexApiException(
        'Could not load this song. Please try another result.',
      );
    }
  }

  Future<Response<Map<String, dynamic>>> _getResolveWithRetry(
    String path, {
    required Map<String, dynamic> queryParameters,
    CancelToken? cancelToken,
  }) async {
    const maxAttempts = 3;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await _dio.get<Map<String, dynamic>>(
          path,
          queryParameters: queryParameters,
          cancelToken: cancelToken,
        );
      } on DioException catch (error) {
        if (CancelToken.isCancel(error) ||
            attempt == maxAttempts ||
            !_shouldRetryResolve(error)) {
          rethrow;
        }
        await Future.delayed(Duration(milliseconds: 350 * attempt));
      }
    }
    throw const AurexApiException(
      'Could not load this song. Please try another result.',
    );
  }

  bool _shouldRetryResolve(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.connectionError) {
      return true;
    }
    final statusCode = error.response?.statusCode;
    return statusCode != null &&
        _retryableResolveStatusCodes.contains(statusCode);
  }

  Future<Track> songFromAurex(
    String query, {
    String format = 'mp3',
    CancelToken? cancelToken,
  }) async {
    final results = await searchAurexSongs(
      query,
      limit: 1,
      cancelToken: cancelToken,
    );
    if (results.isEmpty) {
      throw const AurexApiException(
        'Could not load this song. Please try another result.',
      );
    }
    return resolvePlayableTrack(results.first, format: format);
  }

  Future<Track> resolvePlayableTrack(
    AurexSong song, {
    String format = 'mp3',
    CancelToken? cancelToken,
  }) async {
    final audio = await resolveAurexSong(
      song.videoId,
      format: format,
      cancelToken: cancelToken,
    );
    final playableUrl = audio.playableUrl;
    if (playableUrl == null) {
      throw const AurexApiException(
        'Could not load this song. Please try another result.',
      );
    }
    return song.toTrack(audioUrl: playableUrl);
  }

  Future<Uri?> resolveTrackUri(Track track) async {
    final videoId = track.aurexVideoId;
    if (videoId == null || videoId.trim().isEmpty) {
      return null;
    }
    final audio = await resolveAurexSong(videoId);
    final playableUrl = audio.playableUrl;
    return playableUrl == null ? null : Uri.tryParse(playableUrl);
  }

  AurexSong _songFromJson(Map<String, dynamic> json) {
    final videoId = readString(json['videoId']) ?? '';
    final thumbnail =
        readString(json['thumbnail']) ?? _thumbnailFromVideoId(videoId);
    final channel = readString(json['channel']) ?? 'Aurex Online';
    return AurexSong(
      id: 'aurex-$videoId',
      title: readString(json['title']) ?? 'Untitled',
      artist: channel,
      channel: channel,
      duration: readString(json['duration']),
      thumbnail: thumbnail,
      image: thumbnail,
      videoId: videoId,
      youtubeUrl: readString(json['youtubeUrl']),
    );
  }

  String? _thumbnailFromVideoId(String videoId) {
    final cleanVideoId = videoId.trim();
    if (cleanVideoId.isEmpty) {
      return null;
    }
    return 'https://i.ytimg.com/vi/$cleanVideoId/hqdefault.jpg';
  }
}

class AurexApiException implements Exception {
  const AurexApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class _AurexSearchCacheEntry {
  const _AurexSearchCacheEntry({
    required this.createdAt,
    required this.results,
  });

  final DateTime createdAt;
  final List<AurexSong> results;
}
