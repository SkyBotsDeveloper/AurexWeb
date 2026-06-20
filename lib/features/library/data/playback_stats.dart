import 'dart:math' as math;

import '../../music/domain/music_models.dart';

abstract interface class PlaybackStatsWriter {
  Future<void> recordPlaybackStart(Track track, {DateTime? at});

  Future<void> recordPlaybackOutcome(
    Track track, {
    required Duration listened,
    required bool completed,
    required bool skipped,
    DateTime? at,
  });
}

class PlaybackStats {
  const PlaybackStats({
    required this.trackId,
    required this.source,
    required this.externalId,
    required this.title,
    required this.artist,
    required this.playCount,
    required this.completedPlayCount,
    required this.skipCount,
    required this.totalListenMs,
    required this.lastPlayedAt,
    required this.updatedAt,
  });

  factory PlaybackStats.forTrack(Track track, DateTime now) => PlaybackStats(
    trackId: track.id,
    source: track.source,
    externalId: track.aurexVideoId ?? track.externalId,
    title: track.title,
    artist: track.artistNames,
    playCount: 0,
    completedPlayCount: 0,
    skipCount: 0,
    totalListenMs: 0,
    lastPlayedAt: now,
    updatedAt: now,
  );

  factory PlaybackStats.fromJson(Map<String, dynamic> json) => PlaybackStats(
    trackId: json['trackId'] as String? ?? '',
    source: json['source'] as String? ?? 'local',
    externalId: json['externalId'] as String?,
    title: json['title'] as String? ?? 'Untitled',
    artist: json['artist'] as String? ?? 'Unknown artist',
    playCount: json['playCount'] as int? ?? 0,
    completedPlayCount: json['completedPlayCount'] as int? ?? 0,
    skipCount: json['skipCount'] as int? ?? 0,
    totalListenMs: json['totalListenMs'] as int? ?? 0,
    lastPlayedAt:
        DateTime.tryParse(json['lastPlayedAt'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
    updatedAt:
        DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
  );

  final String trackId;
  final String source;
  final String? externalId;
  final String title;
  final String artist;
  final int playCount;
  final int completedPlayCount;
  final int skipCount;
  final int totalListenMs;
  final DateTime lastPlayedAt;
  final DateTime updatedAt;

  PlaybackStats copyWith({
    String? trackId,
    String? source,
    String? externalId,
    String? title,
    String? artist,
    int? playCount,
    int? completedPlayCount,
    int? skipCount,
    int? totalListenMs,
    DateTime? lastPlayedAt,
    DateTime? updatedAt,
  }) {
    return PlaybackStats(
      trackId: trackId ?? this.trackId,
      source: source ?? this.source,
      externalId: externalId ?? this.externalId,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      playCount: playCount ?? this.playCount,
      completedPlayCount: completedPlayCount ?? this.completedPlayCount,
      skipCount: skipCount ?? this.skipCount,
      totalListenMs: totalListenMs ?? this.totalListenMs,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'trackId': trackId,
    'source': source,
    'externalId': externalId,
    'title': title,
    'artist': artist,
    'playCount': playCount,
    'completedPlayCount': completedPlayCount,
    'skipCount': skipCount,
    'totalListenMs': totalListenMs,
    'lastPlayedAt': lastPlayedAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}

String playbackStatsKey(Track track) {
  final source = track.source.trim().toLowerCase();
  final identity = (track.aurexVideoId ?? track.externalId ?? track.id)
      .trim()
      .toLowerCase();
  return '$source:$identity';
}

List<Track> rankTracksByPlaybackStats(
  Iterable<Track> candidates,
  Iterable<PlaybackStats> stats, {
  int limit = 5,
  DateTime? now,
}) {
  if (limit <= 0) {
    return const [];
  }
  final rankedAt = now ?? DateTime.now();
  final statsList = stats.toList(growable: false);
  final statsByKey = <String, PlaybackStats>{};
  final statsByIdentity = <String, PlaybackStats>{};
  final artistAffinity = <String, int>{};

  for (final item in statsList) {
    statsByKey[_statsRecordKey(item)] = item;
    final identity = _textIdentity(item.title, item.artist);
    if (identity.isNotEmpty) {
      statsByIdentity[identity] = item;
    }
    final affinity =
        item.playCount * 3 + item.completedPlayCount * 6 - item.skipCount * 2;
    for (final artist in _artistParts(item.artist)) {
      artistAffinity.update(
        artist,
        (value) => value + affinity,
        ifAbsent: () => affinity,
      );
    }
  }

  final scored = <({Track track, int index, int score})>[];
  var index = 0;
  for (final track in candidates) {
    final itemStats =
        statsByKey[playbackStatsKey(track)] ??
        statsByIdentity[_textIdentity(track.title, track.artistNames)];
    if (itemStats != null &&
        rankedAt.difference(itemStats.lastPlayedAt) <
            const Duration(minutes: 30)) {
      index += 1;
      continue;
    }
    if (itemStats != null &&
        itemStats.skipCount > itemStats.completedPlayCount &&
        rankedAt.difference(itemStats.lastPlayedAt) < const Duration(days: 7)) {
      index += 1;
      continue;
    }

    var score = 0;
    for (final artist in _artistParts(track.artistNames)) {
      score += (artistAffinity[artist] ?? 0) * 2;
    }
    if (itemStats != null) {
      score += itemStats.completedPlayCount * 12;
      score += itemStats.playCount * 3;
      score += math.min(itemStats.totalListenMs ~/ 60000, 30);
      score -= itemStats.skipCount * 8;
    }
    scored.add((track: track, index: index, score: score));
    index += 1;
  }

  scored.sort((left, right) {
    final scoreOrder = right.score.compareTo(left.score);
    return scoreOrder != 0 ? scoreOrder : left.index.compareTo(right.index);
  });
  return scored.take(limit).map((item) => item.track).toList(growable: false);
}

String _statsRecordKey(PlaybackStats stats) {
  final source = stats.source.trim().toLowerCase();
  final identity = (stats.externalId ?? stats.trackId).trim().toLowerCase();
  return '$source:$identity';
}

String _textIdentity(String title, String artist) {
  final normalizedTitle = _normalize(title);
  final normalizedArtist = _normalize(artist);
  if (normalizedTitle.isEmpty || normalizedArtist.isEmpty) {
    return '';
  }
  return '$normalizedTitle|$normalizedArtist';
}

Set<String> _artistParts(String value) {
  return value
      .split(RegExp(r'[,;&/]'))
      .map(_normalize)
      .where((part) => part.isNotEmpty)
      .toSet();
}

String _normalize(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
}
