import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../../../core/config/app_providers.dart';
import '../../library/data/library_repository.dart';
import '../../music/data/aurex_api_client.dart';
import '../../music/data/music_repository.dart';
import '../../music/domain/music_models.dart';

final autoplayRecommendationServiceProvider =
    Provider<AutoplayRecommendationService>((ref) {
      final libraryRepository = ref.watch(libraryRepositoryProvider);
      return AutoplayRecommendationService(
        ref.watch(musicRepositoryProvider),
        ref.watch(aurexApiClientProvider),
        ref.watch(appLoggerProvider),
        rankSuggestions: (tracks, limit) =>
            libraryRepository.rankSuggestions(tracks, limit: limit),
      );
    });

typedef AutoplaySuggestionLoader =
    Future<List<Track>> Function(
      Track seed,
      List<Track> existingQueue,
      int limit,
    );
typedef AutoplaySuggestionAppender =
    Future<void> Function(List<Track> tracks, String expectedCurrentTrackId);
typedef PersonalizedSuggestionRanker =
    Future<List<Track>> Function(List<Track> tracks, int limit);

class AutoplayRecommendationService {
  AutoplayRecommendationService(
    this._musicRepository,
    this._aurexApiClient,
    this._logger, {
    PersonalizedSuggestionRanker? rankSuggestions,
  }) : _rankSuggestions = rankSuggestions ?? _defaultRanker;

  final MusicRepository _musicRepository;
  final AurexApiClient _aurexApiClient;
  final Logger _logger;
  final PersonalizedSuggestionRanker _rankSuggestions;

  static const _trackFetchTimeout = Duration(seconds: 3);

  Future<List<Track>> loadSuggestions(
    Track seed,
    List<Track> existingQueue,
    int limit,
  ) async {
    if (limit <= 0) {
      return const [];
    }
    final query = '${seed.title} ${seed.artistNames}'.trim();
    if (query.length < 2) {
      return const [];
    }
    return seed.isAurexSource
        ? _loadAurexSuggestions(query, existingQueue, limit)
        : _loadPrimarySuggestions(query, existingQueue, limit);
  }

  Future<List<Track>> _loadPrimarySuggestions(
    String query,
    List<Track> existingQueue,
    int limit,
  ) async {
    final results = await _musicRepository.searchAll(query);
    final suggestions = <Track>[];
    final existingIds = existingQueue
        .map((track) => track.id.trim().toLowerCase())
        .where((id) => id.isNotEmpty)
        .toSet();

    for (final summary in results.songs.take(limit * 3)) {
      if (summary.type != MusicItemType.song ||
          existingIds.contains(summary.id.trim().toLowerCase())) {
        continue;
      }
      try {
        final track = await _musicRepository
            .fetchSong(summary.id)
            .timeout(_trackFetchTimeout);
        final unique = filterUniqueAutoplayTracks(
          [track],
          [...existingQueue, ...suggestions],
          limit: 1,
        );
        if (unique.isNotEmpty) {
          suggestions.add(unique.first);
        }
        if (suggestions.length >= limit * 2) {
          break;
        }
      } catch (error) {
        _logger.d('Skipping primary autoplay suggestion ${summary.id}: $error');
      }
    }
    return _rankSuggestions(suggestions, limit);
  }

  Future<List<Track>> _loadAurexSuggestions(
    String query,
    List<Track> existingQueue,
    int limit,
  ) async {
    final results = await _aurexApiClient.searchAurexSongs(
      query,
      limit: limit * 3,
    );
    final unique = filterUniqueAutoplayTracks(
      results.map((song) => song.toTrack()),
      existingQueue,
      limit: limit * 3,
    );
    return _rankSuggestions(unique, limit);
  }

  static Future<List<Track>> _defaultRanker(
    List<Track> tracks,
    int limit,
  ) async => tracks.take(limit).toList(growable: false);
}

class AutoplayQueueExtender {
  AutoplayQueueExtender({
    required AutoplaySuggestionLoader loadSuggestions,
    required AutoplaySuggestionAppender appendSuggestions,
    required bool Function() isEnabled,
    required bool Function() canExtend,
    required Logger logger,
    this.maxSuggestions = 5,
  }) : _loadSuggestions = loadSuggestions,
       _appendSuggestions = appendSuggestions,
       _isEnabled = isEnabled,
       _canExtend = canExtend,
       _logger = logger;

  final AutoplaySuggestionLoader _loadSuggestions;
  final AutoplaySuggestionAppender _appendSuggestions;
  final bool Function() _isEnabled;
  final bool Function() _canExtend;
  final Logger _logger;
  final int maxSuggestions;
  final Set<String> _attemptedAnchors = {};
  bool _isExtending = false;
  int _generation = 0;

  void reset() {
    _generation += 1;
    _attemptedAnchors.clear();
  }

  Future<bool> maybeExtend({
    required List<Track> queue,
    required int? currentIndex,
  }) async {
    if (!_isEnabled() ||
        !_canExtend() ||
        _isExtending ||
        queue.isEmpty ||
        currentIndex == null ||
        currentIndex < 0 ||
        currentIndex >= queue.length ||
        queue.length - currentIndex - 1 > 1) {
      return false;
    }

    final seed = queue[currentIndex];
    if (!_attemptedAnchors.add(_anchorKey(seed))) {
      return false;
    }

    final generation = _generation;
    _isExtending = true;
    try {
      final suggestions = await _loadSuggestions(
        seed,
        List<Track>.unmodifiable(queue),
        maxSuggestions,
      );
      if (generation != _generation || !_isEnabled() || !_canExtend()) {
        return true;
      }
      final unique = filterUniqueAutoplayTracks(
        suggestions,
        queue,
        limit: maxSuggestions,
      );
      if (unique.isNotEmpty) {
        await _appendSuggestions(unique, seed.id);
      }
    } catch (error) {
      _logger.d('Autoplay queue extension skipped: $error');
    } finally {
      _isExtending = false;
    }
    return true;
  }

  String _anchorKey(Track track) {
    return [
      track.id.trim().toLowerCase(),
      track.aurexVideoId?.trim().toLowerCase() ?? '',
      _songIdentity(track),
    ].join('|');
  }
}

List<Track> filterUniqueAutoplayTracks(
  Iterable<Track> candidates,
  Iterable<Track> existingQueue, {
  int limit = 5,
}) {
  if (limit <= 0) {
    return const [];
  }
  final seenIds = <String>{};
  final seenExternalIds = <String>{};
  final seenIdentities = <String>{};

  void register(Track track) {
    final id = track.id.trim().toLowerCase();
    if (id.isNotEmpty) {
      seenIds.add(id);
    }
    final externalId = (track.aurexVideoId ?? track.externalId)
        ?.trim()
        .toLowerCase();
    if (externalId != null && externalId.isNotEmpty) {
      seenExternalIds.add(externalId);
    }
    final identity = _songIdentity(track);
    if (identity.isNotEmpty) {
      seenIdentities.add(identity);
    }
  }

  for (final track in existingQueue) {
    register(track);
  }

  final unique = <Track>[];
  for (final track in candidates) {
    final id = track.id.trim().toLowerCase();
    final externalId = (track.aurexVideoId ?? track.externalId)
        ?.trim()
        .toLowerCase();
    final identity = _songIdentity(track);
    if ((id.isNotEmpty && seenIds.contains(id)) ||
        (externalId != null &&
            externalId.isNotEmpty &&
            seenExternalIds.contains(externalId)) ||
        (identity.isNotEmpty && seenIdentities.contains(identity))) {
      continue;
    }
    unique.add(track);
    register(track);
    if (unique.length >= limit) {
      break;
    }
  }
  return unique;
}

String _songIdentity(Track track) {
  final title = _normalizeSongPart(track.title);
  final artist = _normalizeSongPart(track.artistNames);
  if (title.isEmpty || artist.isEmpty) {
    return '';
  }
  return '$title|$artist';
}

String _normalizeSongPart(String value) {
  return value
      .toLowerCase()
      .replaceAll('&', ' and ')
      .replaceAll(
        RegExp(
          r'\b(official|video|audio|lyrics?|lyrical|hd|4k|full song)\b',
          caseSensitive: false,
        ),
        ' ',
      )
      .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
}
