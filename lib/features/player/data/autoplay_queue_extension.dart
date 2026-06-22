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
    final queries = _relatedQueriesFor(seed);
    if (queries.isEmpty) {
      return const [];
    }
    return seed.isAurexSource
        ? _loadAurexSuggestions(seed, queries, existingQueue, limit)
        : _loadPrimarySuggestions(seed, queries, existingQueue, limit);
  }

  Future<List<Track>> _loadPrimarySuggestions(
    Track seed,
    List<String> queries,
    List<Track> existingQueue,
    int limit,
  ) async {
    final suggestions = <Track>[];
    final existingIds = existingQueue
        .map(_trackIdKey)
        .where(_isNotEmpty)
        .toSet();

    for (final query in queries) {
      final results = await _musicRepository.searchAll(query);
      for (final summary in results.songs.take(limit * 4)) {
        final summaryId = summary.id.trim().toLowerCase();
        if (summary.type != MusicItemType.song ||
            existingIds.contains(summaryId)) {
          continue;
        }
        if (summaryId.isNotEmpty) {
          existingIds.add(summaryId);
        }
        try {
          final track = await _musicRepository
              .fetchSong(summary.id)
              .timeout(_trackFetchTimeout);
          final unique = filterUniqueAutoplayTracks(
            [track],
            [seed, ...existingQueue, ...suggestions],
            limit: 1,
          );
          if (unique.isNotEmpty) {
            suggestions.add(unique.first);
          }
          if (suggestions.length >= limit * 4) {
            break;
          }
        } catch (error) {
          _logger.d(
            'Skipping primary autoplay suggestion ${summary.id}: $error',
          );
        }
      }
      if (suggestions.length >= limit * 4) {
        break;
      }
    }
    return _rankSuggestions(
      _rankByAutoplaySimilarity(seed, suggestions),
      limit,
    );
  }

  Future<List<Track>> _loadAurexSuggestions(
    Track seed,
    List<String> queries,
    List<Track> existingQueue,
    int limit,
  ) async {
    final results = <Track>[];
    for (final query in queries) {
      final songs = await _aurexApiClient.searchAurexSongs(
        query,
        limit: limit * 4,
      );
      results.addAll(songs.map((song) => song.toTrack()));
      if (results.length >= limit * 5) {
        break;
      }
    }
    final unique = filterUniqueAutoplayTracks(results, [
      seed,
      ...existingQueue,
    ], limit: limit * 4);
    return _rankSuggestions(_rankByAutoplaySimilarity(seed, unique), limit);
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
    DateTime Function()? now,
    this.emptyRetryDelay = const Duration(minutes: 2),
  }) : _loadSuggestions = loadSuggestions,
       _appendSuggestions = appendSuggestions,
       _isEnabled = isEnabled,
       _canExtend = canExtend,
       _logger = logger,
       _now = now ?? DateTime.now;

  final AutoplaySuggestionLoader _loadSuggestions;
  final AutoplaySuggestionAppender _appendSuggestions;
  final bool Function() _isEnabled;
  final bool Function() _canExtend;
  final Logger _logger;
  final int maxSuggestions;
  final DateTime Function() _now;
  final Duration emptyRetryDelay;
  final Set<String> _completedAnchors = {};
  final Map<String, DateTime> _retryAfterByAnchor = {};
  bool _isExtending = false;
  int _generation = 0;

  void reset() {
    _generation += 1;
    _completedAnchors.clear();
    _retryAfterByAnchor.clear();
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
    final anchorKey = _anchorKey(seed);
    if (_completedAnchors.contains(anchorKey)) {
      return false;
    }
    final retryAfter = _retryAfterByAnchor[anchorKey];
    if (retryAfter != null && _now().isBefore(retryAfter)) {
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
        _completedAnchors.add(anchorKey);
        _retryAfterByAnchor.remove(anchorKey);
      } else {
        _retryAfterByAnchor[anchorKey] = _now().add(emptyRetryDelay);
      }
    } catch (error) {
      _retryAfterByAnchor[anchorKey] = _now().add(emptyRetryDelay);
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
  final seenCanonicalTitles = <String>{};

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
    final canonicalTitle = _canonicalSongTitle(track.title);
    if (canonicalTitle.isNotEmpty) {
      seenCanonicalTitles.add(canonicalTitle);
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
    final canonicalTitle = _canonicalSongTitle(track.title);
    if ((id.isNotEmpty && seenIds.contains(id)) ||
        (externalId != null &&
            externalId.isNotEmpty &&
            seenExternalIds.contains(externalId)) ||
        (identity.isNotEmpty && seenIdentities.contains(identity)) ||
        (canonicalTitle.isNotEmpty &&
            seenCanonicalTitles.any(
              (seenTitle) => _titlesTooSimilar(canonicalTitle, seenTitle),
            ))) {
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

List<String> _relatedQueriesFor(Track seed) {
  final artist = seed.artists.isNotEmpty ? seed.artists.first.name.trim() : '';
  final vibes = _inferVibes(seed);
  final queries = <String>[];

  void add(String query) {
    final normalized = query.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.length >= 2 &&
        !queries.any(
          (item) => item.toLowerCase() == normalized.toLowerCase(),
        )) {
      queries.add(normalized);
    }
  }

  for (final vibe in vibes) {
    if (artist.isNotEmpty) {
      add('$artist $vibe songs');
    }
    add('$vibe songs');
  }
  if (artist.isNotEmpty) {
    add('$artist similar songs');
  }
  add('${_canonicalSongTitle(seed.title)} ${artist.isEmpty ? '' : artist}');
  return queries.take(4).toList(growable: false);
}

List<Track> _rankByAutoplaySimilarity(Track seed, List<Track> tracks) {
  final seedVibes = _inferVibes(seed);
  final seedTitle = _canonicalSongTitle(seed.title);
  final seedArtist = _normalizeSongPart(seed.artistNames);
  final indexed = <({Track track, int index, int score})>[];

  for (var index = 0; index < tracks.length; index++) {
    final track = tracks[index];
    final title = _canonicalSongTitle(track.title);
    final artist = _normalizeSongPart(track.artistNames);
    final vibes = _inferVibes(track);
    var score = 0;

    score += seedVibes.intersection(vibes).length * 35;
    if (seedArtist.isNotEmpty && artist == seedArtist && title != seedTitle) {
      score += 10;
    }
    if (seedVibes.isNotEmpty && vibes.isEmpty) {
      score -= 8;
    }
    if (_hasVersionWords(track.title)) {
      score -= 60;
    }
    if (seedTitle.isNotEmpty && _titlesTooSimilar(title, seedTitle)) {
      score -= 120;
    }
    indexed.add((track: track, index: index, score: score));
  }

  indexed.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    return byScore != 0 ? byScore : a.index.compareTo(b.index);
  });
  return indexed.map((item) => item.track).toList(growable: false);
}

Set<String> _inferVibes(Track track) {
  final text = _normalizeSongPart(
    '${track.title} ${track.artistNames} ${track.albumName ?? ''}',
  );
  final vibes = <String>{};
  void match(String vibe, List<String> words) {
    if (words.any((word) => RegExp('\\b$word\\b').hasMatch(text))) {
      vibes.add(vibe);
    }
  }

  match('romantic', [
    'love',
    'romantic',
    'dil',
    'ishq',
    'pyaar',
    'pyar',
    'prem',
    'mohabbat',
    'jaan',
    'tum',
    'tujhe',
  ]);
  match('sad', ['sad', 'dard', 'bewafa', 'yaad', 'judai', 'heartbreak']);
  match('chill', ['chill', 'lofi', 'lo fi', 'acoustic', 'rain', 'sleep']);
  match('devotional', [
    'bhajan',
    'hanuman',
    'ram',
    'shiva',
    'krishna',
    'mata',
    'chalisa',
    'mantra',
    'aarti',
    'devotional',
  ]);
  match('phonk', ['phonk', 'drift', 'cowbell']);
  match('party', ['party', 'dance', 'club', 'dj', 'disco', 'nach']);
  match('rap', ['rap', 'hiphop', 'hip hop', 'trap']);
  match('gym', ['gym', 'workout', 'rage', 'aggressive']);
  return vibes;
}

String _songIdentity(Track track) {
  final title = _canonicalSongTitle(track.title);
  final artist = _normalizeSongPart(track.artistNames);
  if (title.isEmpty || artist.isEmpty) {
    return '';
  }
  return '$title|$artist';
}

String _trackIdKey(Track track) => track.id.trim().toLowerCase();

bool _isNotEmpty(String value) => value.isNotEmpty;

String _canonicalSongTitle(String value) {
  return _normalizeSongPart(value)
      .replaceAll(_versionWordsPattern, ' ')
      .replaceAll(RegExp(r'\b(from|feat|featuring|ft)\b.*$'), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
}

bool _hasVersionWords(String value) =>
    _versionWordsPattern.hasMatch(value.toLowerCase());

bool _titlesTooSimilar(String left, String right) {
  if (left.isEmpty || right.isEmpty) {
    return false;
  }
  if (left == right || left.contains(right) || right.contains(left)) {
    return true;
  }
  final leftTokens = left.split(' ').where(_isNotEmpty).toSet();
  final rightTokens = right.split(' ').where(_isNotEmpty).toSet();
  if (leftTokens.isEmpty || rightTokens.isEmpty) {
    return false;
  }
  final overlap = leftTokens.intersection(rightTokens).length;
  final smaller = leftTokens.length < rightTokens.length
      ? leftTokens.length
      : rightTokens.length;
  return overlap / smaller >= 0.84;
}

String _normalizeSongPart(String value) {
  return value
      .toLowerCase()
      .replaceAll('&', ' and ')
      .replaceAll(_versionWordsPattern, ' ')
      .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
}

final _versionWordsPattern = RegExp(
  r'\b(official|video|audio|lyrics?|lyrical|hd|4k|full|song|remix|mix|live|slowed|reverb|cover|karaoke|instrumental|sped|speed|version|visualizer|status|extended|edit|8d|nightcore)\b',
  caseSensitive: false,
);
