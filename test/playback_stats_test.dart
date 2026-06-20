import 'package:aurex/features/library/data/library_repository.dart';
import 'package:aurex/features/library/data/playback_stats.dart';
import 'package:aurex/features/music/domain/music_models.dart';
import 'package:aurex/features/player/data/playback_stats_tracker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

void main() {
  late Database database;
  late LibraryRepository repository;

  setUp(() async {
    database = await databaseFactoryMemory.openDatabase(
      'playback-stats-${DateTime.now().microsecondsSinceEpoch}',
    );
    repository = LibraryRepository.forDatabase(database);
  });

  tearDown(() => database.close());

  test('play count increments once for one actual playback session', () async {
    final song = track('one');
    final tracker = PlaybackStatsTracker(repository);

    tracker.updateTrack(track: song, isPlaying: true, canRecord: true);
    tracker.updateTrack(track: song, isPlaying: true, canRecord: true);
    tracker.updateTrack(track: song, isPlaying: false, canRecord: true);
    tracker.updateTrack(track: song, isPlaying: true, canRecord: true);
    await tracker.flush();

    final stats = await repository.getPlaybackStats(song);
    expect(stats, isNotNull);
    expect(stats!.playCount, 1);
  });

  test('explicit replay starts a second play session', () async {
    final song = track('replay');
    final tracker = PlaybackStatsTracker(repository);

    tracker.updateTrack(track: song, isPlaying: true, canRecord: true);
    tracker.updatePosition(Duration.zero, duration: song.duration);
    tracker.updatePosition(song.duration!, duration: song.duration);
    tracker.finishForReplay();
    tracker.updateTrack(track: song, isPlaying: true, canRecord: true);
    await tracker.flush();

    final stats = await repository.getPlaybackStats(song);
    expect(stats!.playCount, 2);
    expect(stats.completedPlayCount, 1);
  });

  test('near-end transition records a completed play', () async {
    final song = track('completed');
    final tracker = PlaybackStatsTracker(repository);

    tracker.updateTrack(track: song, isPlaying: true, canRecord: true);
    tracker.updatePosition(Duration.zero, duration: song.duration);
    tracker.updatePosition(
      const Duration(minutes: 2, seconds: 30),
      duration: song.duration,
    );
    tracker.updateTrack(
      track: track('next'),
      isPlaying: false,
      canRecord: true,
    );
    await tracker.flush();

    final stats = await repository.getPlaybackStats(song);
    expect(stats!.completedPlayCount, 1);
    expect(stats.skipCount, 0);
  });

  test('seeking near the end while paused is not a completion', () async {
    final song = track('paused-seek');
    final tracker = PlaybackStatsTracker(repository);

    tracker.updateTrack(track: song, isPlaying: true, canRecord: true);
    tracker.updatePosition(
      const Duration(seconds: 10),
      duration: song.duration,
    );
    tracker.updateTrack(track: song, isPlaying: false, canRecord: true);
    tracker.updatePosition(
      const Duration(minutes: 2, seconds: 50),
      duration: song.duration,
    );
    tracker.updateTrack(
      track: track('next'),
      isPlaying: false,
      canRecord: true,
    );
    await tracker.flush();

    expect((await repository.getPlaybackStats(song))!.completedPlayCount, 0);
  });

  test('early explicit skip increments skip count and listen time', () async {
    final song = track('skipped');
    final tracker = PlaybackStatsTracker(repository);

    tracker.updateTrack(track: song, isPlaying: true, canRecord: true);
    tracker.updatePosition(Duration.zero, duration: song.duration);
    tracker.updatePosition(const Duration(seconds: 5), duration: song.duration);
    tracker.markUserSkip();
    tracker.updateTrack(track: track('next'), isPlaying: true, canRecord: true);
    await tracker.flush();

    final stats = await repository.getPlaybackStats(song);
    expect(stats!.skipCount, 1);
    expect(stats.completedPlayCount, 0);
    expect(stats.totalListenMs, const Duration(seconds: 5).inMilliseconds);
  });

  test('room listener playback does not create local stats', () async {
    final song = track('listener');
    final tracker = PlaybackStatsTracker(repository);

    tracker.updateTrack(track: song, isPlaying: true, canRecord: false);
    tracker.updatePosition(const Duration(seconds: 20));
    await tracker.flush();

    expect(await repository.getPlaybackStats(song), isNull);
  });

  test('ranking prefers strong artist and completed-track history', () {
    final now = DateTime(2026, 6, 21, 12);
    final familiarArtist = track('artist-match', artist: 'Favorite Artist');
    final completedSong = track('completed-song', artist: 'Other Artist');
    final unknown = track('unknown', artist: 'Unknown Artist');
    final ranked = rankTracksByPlaybackStats(
      [unknown, completedSong, familiarArtist],
      [
        stats(
          trackId: 'artist-history',
          artist: 'Favorite Artist',
          playCount: 12,
          completedPlayCount: 8,
          lastPlayedAt: now.subtract(const Duration(days: 2)),
        ),
        stats(
          trackId: completedSong.id,
          artist: completedSong.artistNames,
          playCount: 3,
          completedPlayCount: 3,
          lastPlayedAt: now.subtract(const Duration(hours: 2)),
        ),
      ],
      now: now,
    );

    expect(ranked.first.id, familiarArtist.id);
    expect(ranked[1].id, completedSong.id);
    expect(ranked.last.id, unknown.id);
  });

  test('ranking avoids recently played and recently skipped tracks', () {
    final now = DateTime(2026, 6, 21, 12);
    final recent = track('recent');
    final skipped = track('skipped-recently');
    final eligible = track('eligible');
    final ranked = rankTracksByPlaybackStats(
      [recent, skipped, eligible],
      [
        stats(
          trackId: recent.id,
          artist: recent.artistNames,
          playCount: 4,
          lastPlayedAt: now.subtract(const Duration(minutes: 5)),
        ),
        stats(
          trackId: skipped.id,
          artist: skipped.artistNames,
          playCount: 2,
          skipCount: 2,
          lastPlayedAt: now.subtract(const Duration(days: 1)),
        ),
      ],
      now: now,
    );

    expect(ranked.map((track) => track.id), [eligible.id]);
  });
}

Track track(String id, {String artist = 'Artist'}) {
  return Track(
    id: id,
    title: 'Song $id',
    albumId: null,
    albumName: 'Album',
    duration: const Duration(minutes: 3),
    image: const [],
    artists: [
      ArtistRef(
        id: '$id-artist',
        name: artist,
        role: 'primary',
        image: const [],
        url: null,
      ),
    ],
    audioLinks: const [],
    language: null,
    hasLyrics: false,
    lyricsId: null,
    url: null,
    explicitContent: false,
    year: null,
    label: null,
    playCount: null,
    copyright: null,
  );
}

PlaybackStats stats({
  required String trackId,
  required String artist,
  required int playCount,
  int completedPlayCount = 0,
  int skipCount = 0,
  required DateTime lastPlayedAt,
}) {
  return PlaybackStats(
    trackId: trackId,
    source: 'local',
    externalId: null,
    title: 'Song $trackId',
    artist: artist,
    playCount: playCount,
    completedPlayCount: completedPlayCount,
    skipCount: skipCount,
    totalListenMs:
        completedPlayCount * const Duration(minutes: 3).inMilliseconds,
    lastPlayedAt: lastPlayedAt,
    updatedAt: lastPlayedAt,
  );
}
