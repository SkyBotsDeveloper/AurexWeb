import 'package:aurex/features/music/data/music_repository.dart';
import 'package:aurex/features/music/data/aurex_api_client.dart';
import 'package:aurex/features/music/domain/music_models.dart';
import 'package:aurex/features/music/presentation/collection_detail_screen.dart';
import 'package:aurex/features/music/presentation/open_media_summary.dart';
import 'package:aurex/features/player/data/playback_controller.dart';
import 'package:aurex/features/player/data/playback_models.dart';
import 'package:aurex/features/player/presentation/mini_player.dart';
import 'package:aurex/features/rooms/data/room_models.dart';
import 'package:aurex/features/rooms/data/room_session_controller.dart';
import 'package:aurex/features/search/presentation/search_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:just_audio/just_audio.dart';
import 'package:logger/logger.dart';

void main() {
  final sampleTrack = Track(
    id: 'track-1',
    title: 'Locked Track',
    albumId: 'album-1',
    albumName: 'Night Drive',
    duration: const Duration(minutes: 3, seconds: 12),
    image: const [],
    artists: const [
      ArtistRef(
        id: 'artist-1',
        name: 'Aurex Artist',
        role: 'singer',
        image: [],
        url: null,
      ),
    ],
    audioLinks: const [
      AudioLink(quality: '160kbps', url: 'https://example.com/audio.mp3'),
    ],
    language: 'en',
    hasLyrics: false,
    lyricsId: null,
    url: 'https://example.com/song',
    explicitContent: false,
    year: '2026',
    label: 'Aurex',
    playCount: 42,
    copyright: 'Aurex',
  );

  final sampleCollection = CollectionDetail(
    id: 'album-1',
    title: 'Night Drive',
    type: MusicItemType.album,
    description: 'Late city listening.',
    image: const [],
    artists: sampleTrack.artists,
    songs: [sampleTrack],
    songCount: 1,
    language: 'en',
    year: '2026',
    playCount: 100,
  );

  Track searchTrack(String id, String title) {
    final json = Map<String, dynamic>.from(sampleTrack.toJson())
      ..['id'] = id
      ..['title'] = title;
    return Track.fromJson(json);
  }

  MediaSummary searchSummary(Track track) => MediaSummary(
    id: track.id,
    title: track.title,
    type: MusicItemType.song,
    image: track.image,
    description: track.albumName,
    subtitle: track.albumName,
    url: track.url,
    language: track.language,
    songCount: null,
    followerCount: null,
    releaseDate: null,
    artistText: track.artistNames,
  );

  final sampleRoom = RoomSummary(
    id: 'room-1',
    name: 'Verification Room',
    code: 'ROOM01',
    hostUserId: 'host-1',
    isActive: true,
    maxUsers: 25,
    createdAt: DateTime(2026, 3, 10),
    updatedAt: DateTime(2026, 3, 10),
  );

  Future<ProviderContainer> pumpHarness(
    WidgetTester tester,
    Widget child, {
    FakePlaybackController? playbackController,
    FakeMusicRepository? musicRepository,
    bool? isHost,
  }) async {
    final container = ProviderContainer(
      overrides: [
        playbackControllerProvider.overrideWithValue(
          playbackController ??
              FakePlaybackController(
                PlaybackSnapshot(
                  queue: [sampleTrack],
                  currentIndex: 0,
                  duration: sampleTrack.duration,
                  isPlaying: true,
                  loopMode: LoopMode.off,
                ),
              ),
        ),
        musicRepositoryProvider.overrideWithValue(
          musicRepository ?? FakeMusicRepository(sampleTrack, sampleCollection),
        ),
      ],
    );
    addTearDown(container.dispose);
    if (isHost != null) {
      container
          .read(roomSessionControllerProvider.notifier)
          .activate(room: sampleRoom, isHost: isHost);
    }
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: child),
      ),
    );
    return container;
  }

  testWidgets('mini player disables transport controls for listeners', (
    tester,
  ) async {
    await pumpHarness(
      tester,
      const Scaffold(
        body: SizedBox.shrink(),
        bottomNavigationBar: MiniPlayer(),
      ),
      isHost: false,
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.skip_previous_rounded),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.skip_next_rounded),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton).first).onPressed,
      isNull,
    );
  });

  testWidgets('mini player keeps transport controls enabled for hosts', (
    tester,
  ) async {
    await pumpHarness(
      tester,
      const Scaffold(
        body: SizedBox.shrink(),
        bottomNavigationBar: MiniPlayer(),
      ),
      isHost: true,
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.skip_previous_rounded),
          )
          .onPressed,
      isNotNull,
    );
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.skip_next_rounded),
          )
          .onPressed,
      isNotNull,
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton).first).onPressed,
      isNotNull,
    );
  });

  testWidgets('mini player blocks repeated play taps while resuming', (
    tester,
  ) async {
    await pumpHarness(
      tester,
      const Scaffold(
        body: SizedBox.shrink(),
        bottomNavigationBar: MiniPlayer(),
      ),
      playbackController: FakePlaybackController(
        PlaybackSnapshot(
          queue: [sampleTrack],
          currentIndex: 0,
          duration: sampleTrack.duration,
          isResuming: true,
        ),
      ),
      isHost: true,
    );
    await tester.pump();

    expect(
      tester.widget<FilledButton>(find.byType(FilledButton).first).onPressed,
      isNull,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('collection screen disables play actions for listeners', (
    tester,
  ) async {
    await pumpHarness(
      tester,
      const CollectionDetailScreen(id: 'album-1', kind: CollectionKind.album),
      isHost: false,
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(tester.widget<ListTile>(find.byType(ListTile).first).onTap, isNull);
  });

  testWidgets('collection screen keeps play actions enabled for hosts', (
    tester,
  ) async {
    await pumpHarness(
      tester,
      const CollectionDetailScreen(id: 'album-1', kind: CollectionKind.album),
      isHost: true,
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    expect(
      tester.widget<ListTile>(find.byType(ListTile).first).onTap,
      isNotNull,
    );
  });

  testWidgets('openMediaSummary blocks listener playback entry points', (
    tester,
  ) async {
    final fakePlayback = FakePlaybackController(
      PlaybackSnapshot(
        queue: [sampleTrack],
        currentIndex: 0,
        duration: sampleTrack.duration,
      ),
    );
    final songItem = MediaSummary(
      id: sampleTrack.id,
      title: sampleTrack.title,
      type: MusicItemType.song,
      image: sampleTrack.image,
      description: sampleTrack.albumName,
      subtitle: sampleTrack.albumName,
      url: sampleTrack.url,
      language: sampleTrack.language,
      songCount: null,
      followerCount: null,
      releaseDate: null,
      artistText: sampleTrack.artistNames,
    );

    final container = ProviderContainer(
      overrides: [
        playbackControllerProvider.overrideWithValue(fakePlayback),
        musicRepositoryProvider.overrideWithValue(
          FakeMusicRepository(sampleTrack, sampleCollection),
        ),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(roomSessionControllerProvider.notifier)
        .activate(room: sampleRoom, isHost: false);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => FilledButton(
                onPressed: () => openMediaSummary(context, ref, songItem),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Open'));
    await tester.pump();

    expect(
      find.textContaining('Only the host can control playback'),
      findsOneWidget,
    );
    expect(fakePlayback.playTrackCalls, 0);
  });

  testWidgets('openMediaSummary allows host playback entry points', (
    tester,
  ) async {
    final fakePlayback = FakePlaybackController(
      PlaybackSnapshot(
        queue: [sampleTrack],
        currentIndex: 0,
        duration: sampleTrack.duration,
      ),
    );
    final songItem = MediaSummary(
      id: sampleTrack.id,
      title: sampleTrack.title,
      type: MusicItemType.song,
      image: sampleTrack.image,
      description: sampleTrack.albumName,
      subtitle: sampleTrack.albumName,
      url: sampleTrack.url,
      language: sampleTrack.language,
      songCount: null,
      followerCount: null,
      releaseDate: null,
      artistText: sampleTrack.artistNames,
    );

    final container = ProviderContainer(
      overrides: [
        playbackControllerProvider.overrideWithValue(fakePlayback),
        musicRepositoryProvider.overrideWithValue(
          FakeMusicRepository(sampleTrack, sampleCollection),
        ),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(roomSessionControllerProvider.notifier)
        .activate(room: sampleRoom, isHost: true);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => FilledButton(
                onPressed: () => openMediaSummary(context, ref, songItem),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Open'));
    await tester.pump();

    expect(fakePlayback.playTrackCalls, 1);
  });

  testWidgets('search song tap builds an ordered multi-track queue', (
    tester,
  ) async {
    final tracks = [
      searchTrack('search-1', 'Search Song One'),
      searchTrack('search-2', 'Search Song Two'),
      searchTrack('search-3', 'Search Song Three'),
    ];
    final results = SearchResults(
      topQuery: const [],
      songs: tracks.map(searchSummary).toList(),
      albums: const [],
      artists: const [],
      playlists: const [],
    );
    final fakePlayback = FakePlaybackController(const PlaybackSnapshot());
    final container = ProviderContainer(
      overrides: [
        playbackControllerProvider.overrideWithValue(fakePlayback),
        musicRepositoryProvider.overrideWithValue(
          FakeMusicRepository(
            sampleTrack,
            sampleCollection,
            tracksById: {for (final track in tracks) track.id: track},
            searchResults: results,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(roomSessionControllerProvider.notifier)
        .activate(room: sampleRoom, isHost: true);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SearchScreen()),
      ),
    );
    await tester.enterText(find.byType(TextField), 'search songs');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    final middleSong = find.text('Search Song Two');
    await tester.ensureVisible(middleSong);
    await tester.pumpAndSettle();
    await tester.tap(middleSong);
    await tester.pumpAndSettle();

    expect(fakePlayback.setQueueCalls, 1);
    expect(fakePlayback.snapshot.queue.map((track) => track.id), [
      'search-1',
      'search-2',
      'search-3',
    ]);
    expect(fakePlayback.snapshot.currentIndex, 1);
    expect(fakePlayback.lastInitialTrackId, 'search-2');
  });

  testWidgets('search queue skips a failed result before the selected song', (
    tester,
  ) async {
    final tracks = [
      searchTrack('failed-1', 'Unavailable Search Song'),
      searchTrack('failed-2', 'Selected Search Song'),
      searchTrack('failed-3', 'Available Search Song'),
    ];
    final fakePlayback = FakePlaybackController(const PlaybackSnapshot());
    final container = ProviderContainer(
      overrides: [
        playbackControllerProvider.overrideWithValue(fakePlayback),
        musicRepositoryProvider.overrideWithValue(
          FakeMusicRepository(
            sampleTrack,
            sampleCollection,
            tracksById: {for (final track in tracks) track.id: track},
            failingSongIds: const {'failed-1'},
            searchResults: SearchResults(
              topQuery: const [],
              songs: tracks.map(searchSummary).toList(),
              albums: const [],
              artists: const [],
              playlists: const [],
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SearchScreen()),
      ),
    );
    await tester.enterText(find.byType(TextField), 'failed result');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    final selectedSong = find.text('Selected Search Song');
    await tester.ensureVisible(selectedSong);
    await tester.pumpAndSettle();
    await tester.tap(selectedSong);
    await tester.pumpAndSettle();

    expect(fakePlayback.snapshot.queue.map((track) => track.id), [
      'failed-2',
      'failed-3',
    ]);
    expect(fakePlayback.snapshot.currentIndex, 0);
  });

  testWidgets('online search starts selected song before appending neighbors', (
    tester,
  ) async {
    final songs = [
      _onlineSong('online-1', 'Online Song One'),
      _onlineSong('online-2', 'Online Song Two'),
      _onlineSong('online-3', 'Online Song Three'),
    ];
    final fakePlayback = FakePlaybackController(const PlaybackSnapshot());
    final container = ProviderContainer(
      overrides: [
        playbackControllerProvider.overrideWithValue(fakePlayback),
        musicRepositoryProvider.overrideWithValue(
          FakeMusicRepository(
            sampleTrack,
            sampleCollection,
            searchResults: const SearchResults(
              topQuery: [],
              songs: [],
              albums: [],
              artists: [],
              playlists: [],
            ),
          ),
        ),
        aurexApiClientProvider.overrideWithValue(FakeAurexApiClient(songs)),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SearchScreen()),
      ),
    );
    await tester.enterText(find.byType(TextField), 'online songs');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    final onlineSong = find.text('Online Song Two');
    await tester.ensureVisible(onlineSong);
    await tester.pumpAndSettle();
    await tester.tap(onlineSong);
    await tester.pumpAndSettle();

    expect(fakePlayback.setQueueCalls, 1);
    expect(fakePlayback.snapshot.queue.map((track) => track.id), [
      'aurex-online-2',
      'aurex-online-3',
      'aurex-online-1',
    ]);
    expect(fakePlayback.snapshot.currentIndex, 0);
  });

  testWidgets('search playback remains blocked for room listeners', (
    tester,
  ) async {
    final track = searchTrack('search-locked', 'Locked Search Song');
    final repository = FakeMusicRepository(
      sampleTrack,
      sampleCollection,
      tracksById: {track.id: track},
      searchResults: SearchResults(
        topQuery: const [],
        songs: [searchSummary(track)],
        albums: const [],
        artists: const [],
        playlists: const [],
      ),
    );
    final fakePlayback = FakePlaybackController(const PlaybackSnapshot());
    final container = ProviderContainer(
      overrides: [
        playbackControllerProvider.overrideWithValue(fakePlayback),
        musicRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(roomSessionControllerProvider.notifier)
        .activate(room: sampleRoom, isHost: false);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SearchScreen()),
      ),
    );
    await tester.enterText(find.byType(TextField), 'locked song');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Locked Search Song'));
    await tester.pump();

    expect(repository.fetchSongCalls, 0);
    expect(fakePlayback.setQueueCalls, 0);
    expect(
      find.textContaining('Only the host can control playback'),
      findsOneWidget,
    );
  });
}

class FakePlaybackController implements PlaybackController {
  FakePlaybackController(PlaybackSnapshot snapshot)
    : notifier = ValueNotifier<PlaybackSnapshot>(snapshot);

  @override
  final ValueNotifier<PlaybackSnapshot> notifier;

  int playTrackCalls = 0;
  int setQueueCalls = 0;
  int appendToQueueCalls = 0;
  String? lastInitialTrackId;

  @override
  Future<void> appendToQueue(
    List<Track> tracks, {
    required String expectedCurrentTrackId,
    bool bypassRoomLock = false,
  }) async {
    appendToQueueCalls += 1;
    if (notifier.value.currentTrack?.id != expectedCurrentTrackId) {
      return;
    }
    notifier.value = notifier.value.copyWith(
      queue: [...notifier.value.queue, ...tracks],
    );
  }

  @override
  PlaybackSnapshot get snapshot => notifier.value;

  @override
  Future<void> cycleRepeatMode({bool bypassRoomLock = false}) async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<void> playAtIndex(int index, {bool bypassRoomLock = false}) async {}

  @override
  Future<void> playTrack(Track track, {bool bypassRoomLock = false}) async {
    playTrackCalls += 1;
  }

  @override
  Future<void> seek(Duration position, {bool bypassRoomLock = false}) async {}

  @override
  Future<void> setQueue(
    List<Track> queue, {
    int initialIndex = 0,
    String? initialTrackId,
    Duration initialPosition = Duration.zero,
    bool autoplay = true,
    bool bypassRoomLock = false,
    int? forceAurexRefreshIndex,
  }) async {
    setQueueCalls += 1;
    lastInitialTrackId = initialTrackId;
    final selectedIndex = initialTrackId == null
        ? initialIndex
        : queue.indexWhere((track) => track.id == initialTrackId);
    final safeIndex = selectedIndex < 0 ? initialIndex : selectedIndex;
    notifier.value = notifier.value.copyWith(
      queue: queue,
      currentIndex: safeIndex,
      position: initialPosition,
      duration: queue.isEmpty ? null : queue[safeIndex].duration,
      isPlaying: autoplay,
      clearError: true,
    );
  }

  @override
  Future<void> skipNext({bool bypassRoomLock = false}) async {}

  @override
  Future<void> skipPrevious({bool bypassRoomLock = false}) async {}

  @override
  Future<void> togglePlayPause({bool bypassRoomLock = false}) async {}

  @override
  Future<void> toggleShuffle({bool bypassRoomLock = false}) async {}
}

class FakeMusicRepository implements MusicRepository {
  FakeMusicRepository(
    this._track,
    this._collection, {
    this.tracksById = const {},
    this.failingSongIds = const {},
    this.searchResults,
  });

  final Track _track;
  final CollectionDetail _collection;
  final Map<String, Track> tracksById;
  final Set<String> failingSongIds;
  final SearchResults? searchResults;
  int fetchSongCalls = 0;

  @override
  Future<CollectionDetail> fetchAlbum(String id) async => _collection;

  @override
  Future<DiscoveryDetail> fetchChannel(String id) {
    throw UnimplementedError();
  }

  @override
  Future<ArtistDetail> fetchArtist(String id) {
    throw UnimplementedError();
  }

  @override
  Future<LyricsData> fetchLyrics(String id) {
    throw UnimplementedError();
  }

  @override
  Future<LyricsBundle> fetchBestLyrics(Track track) async =>
      const LyricsBundle();

  @override
  Future<List<HomeSection>> fetchHomeSections() {
    throw UnimplementedError();
  }

  @override
  Future<CollectionDetail> fetchPlaylist(String id) async => _collection;

  @override
  Future<PodcastDetail> fetchPodcast(String id) {
    throw UnimplementedError();
  }

  @override
  Future<DiscoveryDetail> fetchRadioStation(String id) {
    throw UnimplementedError();
  }

  @override
  Future<Track> fetchSong(String id) async {
    fetchSongCalls += 1;
    if (failingSongIds.contains(id)) {
      throw StateError('Song unavailable');
    }
    return tracksById[id] ?? _track;
  }

  @override
  Future<SyncedLyricsData?> fetchSyncedLyrics(String id) async => null;

  @override
  Future<List<HomeSection>> fetchTrendingSections() async => const [];

  @override
  Future<SearchResults> searchAll(String query) async =>
      searchResults ?? (throw UnimplementedError());

  @override
  Future<DiscoverySearchResults> searchDiscovery(String query) {
    throw UnimplementedError();
  }
}

AurexSong _onlineSong(String videoId, String title) => AurexSong(
  id: 'aurex-$videoId',
  title: title,
  artist: 'Aurex Artist',
  channel: 'Aurex Artist',
  duration: '3:30',
  thumbnail: null,
  image: null,
  videoId: videoId,
  youtubeUrl: null,
);

class FakeAurexApiClient extends AurexApiClient {
  FakeAurexApiClient(this.songs) : super(Dio(), Logger());

  final List<AurexSong> songs;

  @override
  Future<List<AurexSong>> searchAurexSongs(
    String query, {
    int limit = 10,
    CancelToken? cancelToken,
    bool forceRefresh = false,
  }) async => songs.take(limit).toList();

  @override
  Future<Track> resolvePlayableTrack(
    AurexSong song, {
    String format = 'mp3',
    CancelToken? cancelToken,
  }) async => song.toTrack(audioUrl: 'https://example.com/${song.videoId}.mp3');
}
