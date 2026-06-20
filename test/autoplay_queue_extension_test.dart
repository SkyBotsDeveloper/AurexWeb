import 'package:aurex/features/music/data/aurex_api_client.dart';
import 'package:aurex/features/music/data/music_repository.dart';
import 'package:aurex/features/music/domain/music_models.dart';
import 'package:aurex/features/player/data/autoplay_queue_extension.dart';
import 'package:aurex/features/rooms/data/room_session_controller.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

void main() {
  test('autoplay disabled does not fetch or extend the queue', () async {
    var fetchCalls = 0;
    var appendCalls = 0;
    final extender = AutoplayQueueExtender(
      loadSuggestions: (seed, queue, limit) async {
        fetchCalls += 1;
        return [track('suggestion')];
      },
      appendSuggestions: (tracks, expectedCurrentTrackId) async {
        appendCalls += 1;
      },
      isEnabled: () => false,
      canExtend: () => true,
      logger: Logger(),
    );

    final attempted = await extender.maybeExtend(
      queue: [track('seed')],
      currentIndex: 0,
    );

    expect(attempted, isFalse);
    expect(fetchCalls, 0);
    expect(appendCalls, 0);
  });

  test('autoplay enabled extends a queue within one item of its end', () async {
    final appended = <Track>[];
    final extender = AutoplayQueueExtender(
      loadSuggestions: (seed, queue, limit) async {
        return List.generate(7, (index) => track('related-$index'));
      },
      appendSuggestions: (tracks, expectedCurrentTrackId) async {
        expect(expectedCurrentTrackId, 'seed');
        appended.addAll(tracks);
      },
      isEnabled: () => true,
      canExtend: () => true,
      logger: Logger(),
    );

    final attempted = await extender.maybeExtend(
      queue: [track('seed'), track('last')],
      currentIndex: 0,
    );

    expect(attempted, isTrue);
    expect(appended, hasLength(5));
  });

  test(
    'room listeners cannot extend but hosts and local playback can',
    () async {
      Future<({int fetchCalls, int appendCalls})> callsFor(
        RoomSessionState state,
      ) async {
        var fetchCalls = 0;
        var appendCalls = 0;
        final extender = AutoplayQueueExtender(
          loadSuggestions: (seed, queue, limit) async {
            fetchCalls += 1;
            return [track('related')];
          },
          appendSuggestions: (tracks, expectedCurrentTrackId) async {
            appendCalls += 1;
          },
          isEnabled: () => true,
          canExtend: () => !state.controlsLocked,
          logger: Logger(),
        );
        await extender.maybeExtend(queue: [track('seed')], currentIndex: 0);
        return (fetchCalls: fetchCalls, appendCalls: appendCalls);
      }

      final listener = await callsFor(
        const RoomSessionState(roomId: 'room-1', isHost: false),
      );
      final host = await callsFor(
        const RoomSessionState(roomId: 'room-1', isHost: true),
      );
      final local = await callsFor(const RoomSessionState());

      expect(listener, (fetchCalls: 0, appendCalls: 0));
      expect(host, (fetchCalls: 1, appendCalls: 1));
      expect(local, (fetchCalls: 1, appendCalls: 1));
    },
  );

  test(
    'failed suggestion fetch is ignored and not retried for one anchor',
    () async {
      var fetchCalls = 0;
      var appendCalls = 0;
      final extender = AutoplayQueueExtender(
        loadSuggestions: (seed, queue, limit) async {
          fetchCalls += 1;
          throw StateError('suggestions unavailable');
        },
        appendSuggestions: (tracks, expectedCurrentTrackId) async {
          appendCalls += 1;
        },
        isEnabled: () => true,
        canExtend: () => true,
        logger: Logger(),
      );
      final queue = [track('seed')];

      expect(await extender.maybeExtend(queue: queue, currentIndex: 0), isTrue);
      expect(
        await extender.maybeExtend(queue: queue, currentIndex: 0),
        isFalse,
      );
      expect(fetchCalls, 1);
      expect(appendCalls, 0);

      extender.reset();
      expect(await extender.maybeExtend(queue: queue, currentIndex: 0), isTrue);
      expect(fetchCalls, 2);
    },
  );

  test('deduplication covers id, external id, and title plus artist', () {
    final existing = track(
      'aurex-video-1',
      title: 'Example Song',
      artist: 'Example Artist',
      source: 'aurex',
      externalId: 'video-1',
    );
    final candidates = [
      track('aurex-video-1', title: 'Different Song'),
      track(
        'different-id',
        title: 'Another Song',
        source: 'aurex',
        externalId: 'video-1',
      ),
      track(
        'identity-duplicate',
        title: 'Example Song (Official Video)',
        artist: 'Example Artist',
      ),
      track('unique', title: 'Unique Song', artist: 'Unique Artist'),
    ];

    final unique = filterUniqueAutoplayTracks(candidates, [existing]);

    expect(unique.map((item) => item.id), ['unique']);
  });

  test(
    'recommendation service uses the matching source for each seed',
    () async {
      final primarySuggestion = track('primary-related');
      final musicRepository = _FakeMusicRepository(
        results: SearchResults(
          topQuery: const [],
          songs: [summary(primarySuggestion.id)],
          albums: const [],
          artists: const [],
          playlists: const [],
        ),
        tracks: {primarySuggestion.id: primarySuggestion},
      );
      final aurexClient = _FakeAurexApiClient([
        const AurexSong(
          id: 'aurex-online-related',
          title: 'Online Related',
          artist: 'Online Artist',
          channel: 'Online Artist',
          duration: '3:00',
          thumbnail: null,
          image: null,
          videoId: 'online-related',
          youtubeUrl: null,
        ),
      ]);
      final service = AutoplayRecommendationService(
        musicRepository,
        aurexClient,
        Logger(),
      );

      final primary = await service.loadSuggestions(track('primary-seed'), [
        track('primary-seed'),
      ], 5);
      final onlineSeed = track(
        'aurex-online-seed',
        source: 'aurex',
        externalId: 'online-seed',
      );
      final online = await service.loadSuggestions(onlineSeed, [onlineSeed], 5);

      expect(primary.map((item) => item.id), ['primary-related']);
      expect(online.map((item) => item.id), ['aurex-online-related']);
      expect(musicRepository.searchCalls, 1);
      expect(aurexClient.searchCalls, 1);
    },
  );

  test(
    'recommendation service applies personalized ranking before limit',
    () async {
      final results = [
        onlineSong('online-1'),
        onlineSong('online-2'),
        onlineSong('online-3'),
      ];
      final service = AutoplayRecommendationService(
        _FakeMusicRepository(
          results: const SearchResults(
            topQuery: [],
            songs: [],
            albums: [],
            artists: [],
            playlists: [],
          ),
          tracks: const {},
        ),
        _FakeAurexApiClient(results),
        Logger(),
        rankSuggestions: (tracks, limit) async =>
            tracks.reversed.take(limit).toList(growable: false),
      );
      final seed = track('aurex-seed', source: 'aurex', externalId: 'seed');

      final suggestions = await service.loadSuggestions(seed, [seed], 2);

      expect(suggestions.map((track) => track.id), [
        'aurex-online-3',
        'aurex-online-2',
      ]);
    },
  );
}

AurexSong onlineSong(String videoId) {
  return AurexSong(
    id: 'aurex-$videoId',
    title: 'Song $videoId',
    artist: 'Online Artist',
    channel: 'Online Artist',
    duration: '3:00',
    thumbnail: null,
    image: null,
    videoId: videoId,
    youtubeUrl: null,
  );
}

Track track(
  String id, {
  String? title,
  String artist = 'Seed Artist',
  String source = 'local',
  String? externalId,
}) {
  return Track(
    id: id,
    title: title ?? 'Song $id',
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
    source: source,
    externalId: externalId,
  );
}

MediaSummary summary(String id) {
  return MediaSummary(
    id: id,
    title: 'Related Song',
    type: MusicItemType.song,
    image: const [],
    description: null,
    subtitle: 'Related Artist',
    url: null,
    language: null,
    songCount: null,
    followerCount: null,
    releaseDate: null,
    artistText: 'Related Artist',
  );
}

class _FakeMusicRepository extends MusicRepository {
  _FakeMusicRepository({required this.results, required this.tracks})
    : super(Dio());

  final SearchResults results;
  final Map<String, Track> tracks;
  int searchCalls = 0;

  @override
  Future<SearchResults> searchAll(String query) async {
    searchCalls += 1;
    return results;
  }

  @override
  Future<Track> fetchSong(String id) async => tracks[id]!;
}

class _FakeAurexApiClient extends AurexApiClient {
  _FakeAurexApiClient(this.results) : super(Dio(), Logger());

  final List<AurexSong> results;
  int searchCalls = 0;

  @override
  Future<List<AurexSong>> searchAurexSongs(
    String query, {
    int limit = 10,
    CancelToken? cancelToken,
    bool forceRefresh = false,
  }) async {
    searchCalls += 1;
    return results.take(limit).toList(growable: false);
  }
}
