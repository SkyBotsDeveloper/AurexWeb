import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../utils/json_utils.dart';

class CleanArtworkResolver {
  CleanArtworkResolver._();

  static const _webBaseUrl = '/artwork-api';
  static const _baseUrl = String.fromEnvironment('CLEAN_ARTWORK_API_BASE_URL');

  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: _effectiveBaseUrl,
      connectTimeout: const Duration(seconds: 4),
      receiveTimeout: const Duration(seconds: 6),
      responseType: ResponseType.json,
    ),
  );

  static final Map<String, Future<String?>> _cache = {};

  static String get _effectiveBaseUrl {
    final configured = _baseUrl.trim();
    if (configured.isNotEmpty) {
      if (!kIsWeb && configured.startsWith('/')) {
        return 'https://elite-music-api.vercel.app';
      }
      return configured;
    }
    return kIsWeb ? _webBaseUrl : 'https://elite-music-api.vercel.app';
  }

  static Future<String?> resolve({
    required String query,
    String? type,
    String? subtitle,
  }) {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      return Future.value(null);
    }

    final cacheKey = [
      _normalize(cleanQuery),
      type?.trim().toLowerCase() ?? '',
      _normalize(subtitle ?? ''),
    ].join('|');

    return _cache.putIfAbsent(
      cacheKey,
      () => _resolve(query: cleanQuery, type: type, subtitle: subtitle),
    );
  }

  static Future<String?> _resolve({
    required String query,
    String? type,
    String? subtitle,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        _searchPath(type),
        queryParameters: {'query': query, 'limit': 6},
      );
      final candidates = _extractCandidates(response.data, type);
      if (candidates.isEmpty) {
        return null;
      }

      final normalizedQuery = _normalize(query);
      final normalizedSubtitle = _normalize(subtitle ?? '');
      Map<String, dynamic>? bestCandidate;
      var bestScore = -1 << 20;

      for (final candidate in candidates) {
        final score = _scoreCandidate(
          candidate,
          normalizedQuery,
          normalizedSubtitle,
        );
        if (score > bestScore) {
          bestScore = score;
          bestCandidate = candidate;
        }
      }

      if (bestCandidate == null || bestScore < 45) {
        return null;
      }
      return _bestImageUrl(bestCandidate);
    } on DioException {
      return null;
    } catch (_) {
      return null;
    }
  }

  static String _searchPath(String? type) {
    return switch (type?.toLowerCase()) {
      'song' => '/api/search/songs',
      'album' => '/api/search/albums',
      'artist' => '/api/search/artists',
      'playlist' => '/api/search/playlists',
      _ => '/api/search',
    };
  }

  static List<Map<String, dynamic>> _extractCandidates(
    Map<String, dynamic>? response,
    String? type,
  ) {
    final data = readMap(response?['data']);
    final directResults = readMapList(data['results']);
    if (directResults.isNotEmpty) {
      return directResults;
    }

    final groupedKey = switch (type?.toLowerCase()) {
      'song' => 'songs',
      'album' => 'albums',
      'artist' => 'artists',
      'playlist' => 'playlists',
      _ => null,
    };

    if (groupedKey != null) {
      final groupedResults = readMapList(readMap(data[groupedKey])['results']);
      if (groupedResults.isNotEmpty) {
        return groupedResults;
      }
    }

    return ['songs', 'albums', 'artists', 'playlists']
        .expand((key) => readMapList(readMap(data[key])['results']))
        .toList(growable: false);
  }

  static int _scoreCandidate(
    Map<String, dynamic> candidate,
    String normalizedQuery,
    String normalizedSubtitle,
  ) {
    final title = _normalize(
      readString(candidate['title']) ?? readString(candidate['name']) ?? '',
    );
    final subtitle = _normalize(
      [
        readString(candidate['subtitle']),
        readString(readMap(candidate['author'])['name']),
        ...readMapList(candidate['artists']).map((artist) => artist['name']),
      ].whereType<String>().join(' '),
    );

    var score = 0;
    if (title == normalizedQuery) {
      score += 90;
    } else if (title.startsWith(normalizedQuery) ||
        normalizedQuery.startsWith(title)) {
      score += 75;
    } else if (title.contains(normalizedQuery) ||
        normalizedQuery.contains(title)) {
      score += 55;
    }

    var subtitleMatches = 0;
    if (normalizedSubtitle.isNotEmpty) {
      for (final token in normalizedSubtitle.split(' ')) {
        if (token.length >= 4 && subtitle.contains(token)) {
          subtitleMatches++;
          score += 6;
        }
      }
      if (subtitleMatches == 0 && subtitle.isNotEmpty) {
        score -= 35;
      }
    }

    if (_bestImageUrl(candidate) != null) {
      score += 12;
    }
    return score;
  }

  static String? _bestImageUrl(Map<String, dynamic> candidate) {
    final images = [
      ...readMapList(candidate['image']),
      ...readMapList(candidate['thumbnails']),
    ];
    if (images.isEmpty) {
      return null;
    }

    images.sort((left, right) {
      final leftScore = _imageScore(left);
      final rightScore = _imageScore(right);
      return rightScore.compareTo(leftScore);
    });
    return readString(images.first['url']);
  }

  static int _imageScore(Map<String, dynamic> image) {
    final width = readInt(image['width']) ?? 0;
    final height = readInt(image['height']) ?? 0;
    final squareBonus = width > 0 && height > 0 && (width - height).abs() <= 8
        ? 1000000
        : 0;
    return squareBonus + (width * height);
  }

  static String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'&[^;\s]+;'), ' ')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
  }
}
