import 'dart:async';

import 'package:aurex/features/library/data/library_models.dart';
import 'package:aurex/features/music/data/music_repository.dart';
import 'package:aurex/features/music/domain/music_models.dart';
import 'package:aurex/features/music/presentation/track_support_actions.dart';
import 'package:aurex/features/player/data/download_manager.dart';
import 'package:aurex/features/player/data/playback_controller.dart';
import 'package:aurex/features/player/data/playback_models.dart';
import 'package:aurex/features/player/presentation/player_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const firstLyrics = 'First track lyrics';
  const secondLyrics = 'Second track lyrics';

  Future<({_FakePlaybackController playback, ProviderContainer container})>
  pumpPlayer(
    WidgetTester tester, {
    required List<Track> tracks,
    required _LyricsRepository repository,
  }) async {
    final playback = _FakePlaybackController(
      PlaybackSnapshot(
        queue: tracks,
        currentIndex: 0,
        duration: tracks.first.duration,
        isPlaying: true,
      ),
    );
    final downloads = _FakeDownloadManager();
    final container = ProviderContainer(
      overrides: [
        playbackControllerProvider.overrideWithValue(playback),
        musicRepositoryProvider.overrideWithValue(repository),
        likedTrackIdsStreamProvider.overrideWith(
          (ref) => Stream.value(const <String>{}),
        ),
        downloadedTracksStreamProvider.overrideWith(
          (ref) => Stream.value(const <DownloadRecord>[]),
        ),
        downloadManagerProvider.overrideWithValue(downloads),
      ],
    );
    addTearDown(() {
      playback.notifier.dispose();
      downloads.dispose();
      container.dispose();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: PlayerScreen()),
      ),
    );
    return (playback: playback, container: container);
  }

  testWidgets('lyrics stay hidden until the available button is tapped', (
    tester,
  ) async {
    final track = _track('first');
    final repository = _LyricsRepository({
      track.id: () async => _plainLyrics(firstLyrics),
    });

    await pumpPlayer(tester, tracks: [track], repository: repository);
    await tester.pump();

    final lyricsButton = find.widgetWithText(FilledButton, 'Lyrics');
    expect(lyricsButton, findsOneWidget);
    expect(find.text(firstLyrics), findsNothing);

    await tester.ensureVisible(lyricsButton);
    await tester.tap(lyricsButton);
    await tester.pump();

    expect(find.text('Hide Lyrics'), findsOneWidget);
    expect(find.text(firstLyrics), findsOneWidget);
  });

  testWidgets('lyrics button stays hidden while availability is loading', (
    tester,
  ) async {
    final track = _track('loading');
    final completer = Completer<LyricsBundle>();
    final repository = _LyricsRepository({track.id: () => completer.future});

    await pumpPlayer(tester, tracks: [track], repository: repository);
    await tester.pump();

    expect(find.widgetWithText(FilledButton, 'Lyrics'), findsNothing);
    expect(find.text('Lyrics unavailable'), findsNothing);

    completer.complete(_plainLyrics(firstLyrics));
    await tester.pump();
    await tester.pump();

    expect(find.widgetWithText(FilledButton, 'Lyrics'), findsOneWidget);
    expect(find.text(firstLyrics), findsNothing);
  });

  testWidgets('unavailable lyrics render neither button nor empty panel', (
    tester,
  ) async {
    final track = _track('unavailable');
    final repository = _LyricsRepository({
      track.id: () async => const LyricsBundle(),
    });

    await pumpPlayer(tester, tracks: [track], repository: repository);
    await tester.pump();

    expect(find.widgetWithText(FilledButton, 'Lyrics'), findsNothing);
    expect(find.text('Lyrics unavailable'), findsNothing);
    expect(find.byIcon(Icons.lyrics_outlined), findsNothing);
  });

  testWidgets('track change closes lyrics and checks the new track', (
    tester,
  ) async {
    final first = _track('first');
    final second = _track('second');
    final repository = _LyricsRepository({
      first.id: () async => _plainLyrics(firstLyrics),
      second.id: () async => _plainLyrics(secondLyrics),
    });
    final harness = await pumpPlayer(
      tester,
      tracks: [first, second],
      repository: repository,
    );
    await tester.pump();

    final lyricsButton = find.widgetWithText(FilledButton, 'Lyrics');
    await tester.ensureVisible(lyricsButton);
    await tester.tap(lyricsButton);
    await tester.pump();
    expect(find.text(firstLyrics), findsOneWidget);

    harness.playback.notifier.value = PlaybackSnapshot(
      queue: [first, second],
      currentIndex: 1,
      duration: second.duration,
      isPlaying: true,
    );
    await tester.pump();
    await tester.pump();

    expect(repository.requestedTrackIds, [first.id, second.id]);
    expect(find.text(firstLyrics), findsNothing);
    expect(find.text(secondLyrics), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Lyrics'), findsOneWidget);
    expect(find.text('Hide Lyrics'), findsNothing);
  });

  testWidgets('failed lookup closes old lyrics without unavailable panel', (
    tester,
  ) async {
    final first = _track('first');
    final failing = _track('failing');
    final repository = _LyricsRepository({
      first.id: () async => _plainLyrics(firstLyrics),
      failing.id: () => Future<LyricsBundle>.error(StateError('offline')),
    });
    final harness = await pumpPlayer(
      tester,
      tracks: [first, failing],
      repository: repository,
    );
    await tester.pump();

    final lyricsButton = find.widgetWithText(FilledButton, 'Lyrics');
    await tester.ensureVisible(lyricsButton);
    await tester.tap(lyricsButton);
    await tester.pump();
    expect(find.text(firstLyrics), findsOneWidget);

    harness.playback.notifier.value = PlaybackSnapshot(
      queue: [first, failing],
      currentIndex: 1,
      duration: failing.duration,
      isPlaying: true,
    );
    await tester.pump();
    await tester.pump();

    expect(find.text(firstLyrics), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Lyrics'), findsNothing);
    expect(find.text('Lyrics unavailable'), findsNothing);
  });
}

Track _track(String id) => Track(
  id: id,
  title: 'Track $id',
  albumId: 'album-$id',
  albumName: 'Album $id',
  duration: const Duration(minutes: 3),
  image: const [],
  artists: const [
    ArtistRef(
      id: 'artist',
      name: 'Artist',
      role: 'primary',
      image: [],
      url: null,
    ),
  ],
  audioLinks: const [],
  language: 'en',
  hasLyrics: true,
  lyricsId: 'lyrics-$id',
  url: null,
  explicitContent: false,
  year: '2026',
  label: 'Aurex',
  playCount: 0,
  copyright: 'Aurex',
);

LyricsBundle _plainLyrics(String text) => LyricsBundle(
  plain: LyricsData(
    id: 'plain',
    lyrics: text,
    lines: [text],
    snippet: null,
    copyright: null,
  ),
);

class _LyricsRepository implements MusicRepository {
  _LyricsRepository(this.lookups);

  final Map<String, Future<LyricsBundle> Function()> lookups;
  final List<String> requestedTrackIds = [];

  @override
  Future<LyricsBundle> fetchBestLyrics(Track track) {
    requestedTrackIds.add(track.id);
    return lookups[track.id]?.call() ?? Future.value(const LyricsBundle());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePlaybackController implements PlaybackController {
  _FakePlaybackController(PlaybackSnapshot snapshot)
    : notifier = ValueNotifier(snapshot);

  @override
  final ValueNotifier<PlaybackSnapshot> notifier;

  @override
  PlaybackSnapshot get snapshot => notifier.value;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeDownloadManager implements DownloadManager {
  @override
  final ValueNotifier<Map<String, DownloadTaskProgress>> progressNotifier =
      ValueNotifier(const {});

  @override
  void dispose() => progressNotifier.dispose();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
