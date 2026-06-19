import 'dart:io';
import 'dart:typed_data';

import 'package:aurex/features/music/domain/music_models.dart';
import 'package:aurex/features/player/data/aurex_audio_cache_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;
import 'package:sembast/sembast_memory.dart';

void main() {
  late Database database;
  late Directory cacheDirectory;
  late Dio dio;
  late AurexAudioCacheRepository repository;

  setUp(() async {
    database = await databaseFactoryMemory.openDatabase(
      'aurex-audio-cache-${DateTime.now().microsecondsSinceEpoch}',
    );
    cacheDirectory = await Directory.systemTemp.createTemp(
      'aurex-audio-cache-test-',
    );
    dio = Dio();
    repository = AurexAudioCacheRepository(
      database,
      dio,
      Logger(),
      cacheDirectoryPath: () async => cacheDirectory.path,
    );
  });

  tearDown(() async {
    dio.close(force: true);
    await database.close();
    if (await cacheDirectory.exists()) {
      await cacheDirectory.delete(recursive: true);
    }
  });

  test(
    'valid cache hit returns a file URI and refreshes usage metadata',
    () async {
      final track = aurexTrack('valid-video');
      final file = File(p.join(cacheDirectory.path, 'valid-video.mp3'));
      await file.writeAsBytes([1, 2, 3]);
      final now = DateTime.now();
      final originalExpiry = now.add(const Duration(hours: 1));
      await repository.upsert(
        cacheRecord(
          track: track,
          file: file,
          createdAt: now.subtract(const Duration(hours: 2)),
          expiresAt: originalExpiry,
          playCount: 2,
        ),
      );

      final uri = await repository.getCachedUri(track);
      final updated = await repository.getRecord('valid-video');

      expect(uri, Uri.file(file.path));
      expect(updated, isNotNull);
      expect(updated!.playCount, 3);
      expect(updated.lastUsedAt.isAfter(now), isTrue);
      expect(updated.expiresAt.isAfter(originalExpiry), isTrue);
    },
  );

  test('missing cache file removes stale metadata', () async {
    final track = aurexTrack('missing-video');
    final file = File(p.join(cacheDirectory.path, 'missing-video.mp3'));
    final now = DateTime.now();
    await repository.upsert(
      cacheRecord(
        track: track,
        file: file,
        createdAt: now,
        expiresAt: now.add(const Duration(hours: 1)),
      ),
    );

    expect(await repository.getCachedUri(track), isNull);
    expect(await repository.getRecord('missing-video'), isNull);
  });

  test('expired cache removes both file and metadata', () async {
    final track = aurexTrack('expired-video');
    final file = File(p.join(cacheDirectory.path, 'expired-video.mp3'));
    await file.writeAsBytes([1, 2, 3]);
    final now = DateTime.now();
    await repository.upsert(
      cacheRecord(
        track: track,
        file: file,
        createdAt: now.subtract(const Duration(days: 3)),
        expiresAt: now.subtract(const Duration(minutes: 1)),
      ),
    );

    expect(await repository.getCachedUri(track), isNull);
    expect(await file.exists(), isFalse);
    expect(await repository.getRecord('expired-video'), isNull);
  });

  test('download uses a safe partial file before storing metadata', () async {
    dio.httpClientAdapter = _BytesAdapter([9, 8, 7, 6]);
    final track = aurexTrack('unsafe/video');

    await repository.cacheResolvedTrack(
      track,
      Uri.parse('https://audio.example.com/stream'),
    );

    final record = await repository.getRecord('unsafe/video');
    expect(record, isNotNull);
    expect(p.basename(record!.localFilePath), 'unsafe_video.mp3');
    expect(record.fileSizeBytes, 4);
    expect(record.playCount, 1);
    expect(await File(record.localFilePath).readAsBytes(), [9, 8, 7, 6]);
    expect(await File('${record.localFilePath}.part').exists(), isFalse);
  });

  test('concurrent requests share one cache download', () async {
    final adapter = _BytesAdapter([
      1,
      2,
      3,
    ], delay: const Duration(milliseconds: 20));
    dio.httpClientAdapter = adapter;
    final track = aurexTrack('shared-video');
    final sourceUri = Uri.parse('https://audio.example.com/shared-stream');

    await Future.wait([
      repository.cacheResolvedTrack(track, sourceUri),
      repository.cacheResolvedTrack(track, sourceUri),
    ]);

    expect(adapter.requestCount, 1);
    expect(await repository.getRecord('shared-video'), isNotNull);
  });
}

AurexAudioCacheRecord cacheRecord({
  required Track track,
  required File file,
  required DateTime createdAt,
  required DateTime expiresAt,
  int playCount = 1,
}) {
  return AurexAudioCacheRecord(
    videoId: track.aurexVideoId!,
    trackId: track.id,
    title: track.title,
    artist: track.artistNames,
    artworkUrl: track.artworkUrl,
    localFilePath: file.path,
    fileSizeBytes: 3,
    createdAt: createdAt,
    lastUsedAt: createdAt,
    expiresAt: expiresAt,
    playCount: playCount,
  );
}

Track aurexTrack(String videoId) {
  return Track(
    id: 'aurex-$videoId',
    title: 'Cached Song',
    albumId: null,
    albumName: 'Aurex Online',
    duration: const Duration(minutes: 3),
    image: const [
      MediaImage(quality: '500x500', url: 'https://example.com/cover.jpg'),
    ],
    artists: const [
      ArtistRef(
        id: 'artist',
        name: 'Cached Artist',
        role: 'primary',
        image: [],
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
    source: 'aurex',
    externalId: videoId,
  );
}

class _BytesAdapter implements HttpClientAdapter {
  _BytesAdapter(this.bytes, {this.delay = Duration.zero});

  final List<int> bytes;
  final Duration delay;
  int requestCount = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestCount += 1;
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    return ResponseBody.fromBytes(
      bytes,
      200,
      headers: {
        Headers.contentLengthHeader: [bytes.length.toString()],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
