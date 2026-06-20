import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sembast/sembast.dart';

import '../../../core/config/app_providers.dart';
import '../../../core/storage/app_database.dart';
import '../../music/domain/music_models.dart';
import 'library_models.dart';
import 'playback_stats.dart';

final libraryRepositoryProvider = Provider<LibraryRepository>(
  (ref) => LibraryRepository(ref.watch(appDatabaseProvider)),
);

class LibraryRepository implements PlaybackStatsWriter {
  LibraryRepository(AppDatabase database) : _db = database.db;

  LibraryRepository.forDatabase(this._db);

  final Database _db;

  static final _likesStore = stringMapStoreFactory.store(
    'library_liked_tracks',
  );
  static final _historyStore = stringMapStoreFactory.store(
    'library_history_tracks',
  );
  static final _downloadsStore = stringMapStoreFactory.store(
    'library_downloads',
  );
  static final _playlistsStore = stringMapStoreFactory.store(
    'library_playlists',
  );
  static final _playbackStatsStore = stringMapStoreFactory.store(
    'library_playback_stats',
  );

  Stream<List<Track>> watchLikedTracks() {
    final query = _likesStore.query(
      finder: Finder(sortOrders: [SortOrder('savedAt', false)]),
    );
    return query
        .onSnapshots(_db)
        .map(
          (snapshots) => snapshots
              .map(
                (snapshot) => Track.fromJson(
                  Map<String, dynamic>.from(snapshot.value['track'] as Map),
                ),
              )
              .toList(),
        );
  }

  Stream<Set<String>> watchLikedIds() {
    return watchLikedTracks().map(
      (tracks) => tracks.map((track) => track.id).toSet(),
    );
  }

  Future<bool> isLiked(String trackId) =>
      _likesStore.record(trackId).exists(_db);

  Future<void> toggleLike(Track track) async {
    final record = _likesStore.record(track.id);
    if (await record.exists(_db)) {
      await record.delete(_db);
      return;
    }
    await record.put(_db, {
      'savedAt': DateTime.now().toIso8601String(),
      'track': track.toJson(),
    });
  }

  Future<void> addToHistory(Track track) async {
    await _historyStore.record(track.id).put(_db, {
      'lastPlayedAt': DateTime.now().toIso8601String(),
      'track': track.toJson(),
    });
  }

  @override
  Future<void> recordPlaybackStart(Track track, {DateTime? at}) async {
    final now = at ?? DateTime.now();
    final record = _playbackStatsStore.record(playbackStatsKey(track));
    await _db.transaction((transaction) async {
      final raw = await record.get(transaction);
      final current = raw == null
          ? PlaybackStats.forTrack(track, now)
          : PlaybackStats.fromJson(raw);
      await record.put(
        transaction,
        current
            .copyWith(
              trackId: track.id,
              source: track.source,
              externalId: track.aurexVideoId ?? track.externalId,
              title: track.title,
              artist: track.artistNames,
              playCount: current.playCount + 1,
              lastPlayedAt: now,
              updatedAt: now,
            )
            .toJson(),
      );
    });
  }

  @override
  Future<void> recordPlaybackOutcome(
    Track track, {
    required Duration listened,
    required bool completed,
    required bool skipped,
    DateTime? at,
  }) async {
    final now = at ?? DateTime.now();
    final record = _playbackStatsStore.record(playbackStatsKey(track));
    await _db.transaction((transaction) async {
      final raw = await record.get(transaction);
      final current = raw == null
          ? PlaybackStats.forTrack(track, now)
          : PlaybackStats.fromJson(raw);
      await record.put(
        transaction,
        current
            .copyWith(
              trackId: track.id,
              source: track.source,
              externalId: track.aurexVideoId ?? track.externalId,
              title: track.title,
              artist: track.artistNames,
              completedPlayCount:
                  current.completedPlayCount + (completed ? 1 : 0),
              skipCount: current.skipCount + (skipped ? 1 : 0),
              totalListenMs: current.totalListenMs + listened.inMilliseconds,
              updatedAt: now,
            )
            .toJson(),
      );
    });
  }

  Future<PlaybackStats?> getPlaybackStats(Track track) async {
    final raw = await _playbackStatsStore
        .record(playbackStatsKey(track))
        .get(_db);
    return raw == null ? null : PlaybackStats.fromJson(raw);
  }

  Future<List<PlaybackStats>> getAllPlaybackStats() async {
    final snapshots = await _playbackStatsStore.find(_db);
    return snapshots
        .map((snapshot) => PlaybackStats.fromJson(snapshot.value))
        .toList(growable: false);
  }

  Future<List<Track>> rankSuggestions(
    Iterable<Track> candidates, {
    int limit = 5,
    DateTime? now,
  }) async {
    final candidateList = candidates.toList(growable: false);
    if (candidateList.length <= 1 || limit <= 0) {
      return candidateList.take(limit).toList(growable: false);
    }
    return rankTracksByPlaybackStats(
      candidateList,
      await getAllPlaybackStats(),
      limit: limit,
      now: now,
    );
  }

  Stream<List<Track>> watchHistory() {
    final query = _historyStore.query(
      finder: Finder(sortOrders: [SortOrder('lastPlayedAt', false)]),
    );
    return query
        .onSnapshots(_db)
        .map(
          (snapshots) => snapshots
              .map(
                (snapshot) => Track.fromJson(
                  Map<String, dynamic>.from(snapshot.value['track'] as Map),
                ),
              )
              .toList(),
        );
  }

  Stream<List<DownloadRecord>> watchDownloads() {
    final query = _downloadsStore.query(
      finder: Finder(sortOrders: [SortOrder('downloadedAt', false)]),
    );
    return query
        .onSnapshots(_db)
        .map(
          (snapshots) => snapshots
              .map((snapshot) => DownloadRecord.fromJson(snapshot.value))
              .toList(),
        );
  }

  Future<void> upsertDownload(DownloadRecord record) async {
    await _downloadsStore.record(record.track.id).put(_db, record.toJson());
  }

  Future<DownloadRecord?> getDownload(String trackId) async {
    final snapshot = await _downloadsStore.record(trackId).get(_db);
    return snapshot == null ? null : DownloadRecord.fromJson(snapshot);
  }

  Future<void> removeDownload(String trackId) async {
    await _downloadsStore.record(trackId).delete(_db);
  }

  Future<int> totalDownloadBytes() async {
    final snapshots = await _downloadsStore.find(_db);
    var total = 0;
    for (final snapshot in snapshots) {
      total += DownloadRecord.fromJson(snapshot.value).fileSizeBytes ?? 0;
    }
    return total;
  }

  Stream<List<UserPlaylist>> watchPlaylists() {
    final query = _playlistsStore.query(
      finder: Finder(sortOrders: [SortOrder('updatedAt', false)]),
    );
    return query
        .onSnapshots(_db)
        .map(
          (snapshots) => snapshots
              .map((snapshot) => UserPlaylist.fromJson(snapshot.value))
              .toList(),
        );
  }

  Stream<UserPlaylist?> watchPlaylist(String playlistId) {
    return _playlistsStore
        .record(playlistId)
        .onSnapshot(_db)
        .map(
          (snapshot) =>
              snapshot == null ? null : UserPlaylist.fromJson(snapshot.value),
        );
  }

  Future<UserPlaylist> createPlaylist(String name) async {
    final playlist = UserPlaylist.create(name);
    await _playlistsStore.record(playlist.id).put(_db, playlist.toJson());
    return playlist;
  }

  Future<void> addTrackToPlaylist(String playlistId, Track track) async {
    final current = await _playlistsStore.record(playlistId).get(_db);
    if (current == null) {
      return;
    }
    final playlist = UserPlaylist.fromJson(current);
    final alreadyInPlaylist = playlist.tracks.any(
      (existingTrack) => existingTrack.id == track.id,
    );
    final updated = playlist.copyWith(
      updatedAt: DateTime.now(),
      tracks: alreadyInPlaylist ? playlist.tracks : [...playlist.tracks, track],
    );
    await _playlistsStore.record(playlistId).put(_db, updated.toJson());
  }
}
