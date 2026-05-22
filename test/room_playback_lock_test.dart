import 'package:aurex/features/music/data/music_repository.dart';
import 'package:aurex/features/music/domain/music_models.dart';
import 'package:aurex/features/music/presentation/collection_detail_screen.dart';
import 'package:aurex/features/music/presentation/open_media_summary.dart';
import 'package:aurex/features/player/data/playback_controller.dart';
import 'package:aurex/features/player/data/playback_models.dart';
import 'package:aurex/features/player/presentation/mini_player.dart';
import 'package:aurex/features/rooms/data/room_models.dart';
import 'package:aurex/features/rooms/data/room_session_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';

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
}

class FakePlaybackController implements PlaybackController {
  FakePlaybackController(PlaybackSnapshot snapshot)
    : notifier = ValueNotifier<PlaybackSnapshot>(snapshot);

  @override
  final ValueNotifier<PlaybackSnapshot> notifier;

  int playTrackCalls = 0;

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
    Duration initialPosition = Duration.zero,
    bool autoplay = true,
    bool bypassRoomLock = false,
    int? forceAurexRefreshIndex,
  }) async {
    notifier.value = notifier.value.copyWith(
      queue: queue,
      currentIndex: initialIndex,
      position: initialPosition,
      duration: queue.isEmpty ? null : queue[initialIndex].duration,
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
  FakeMusicRepository(this._track, this._collection);

  final Track _track;
  final CollectionDetail _collection;

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
  Future<Track> fetchSong(String id) async => _track;

  @override
  Future<SyncedLyricsData?> fetchSyncedLyrics(String id) async => null;

  @override
  Future<List<HomeSection>> fetchTrendingSections() async => const [];

  @override
  Future<SearchResults> searchAll(String query) {
    throw UnimplementedError();
  }

  @override
  Future<DiscoverySearchResults> searchDiscovery(String query) {
    throw UnimplementedError();
  }
}
