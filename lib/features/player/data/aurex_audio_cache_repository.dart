import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;
import 'package:sembast/sembast.dart';

import '../../../core/config/app_providers.dart';
import '../../../core/storage/app_paths.dart';
import '../../../core/storage/file_ops.dart';
import '../../music/domain/music_models.dart';

final aurexAudioCacheRepositoryProvider = Provider<AurexAudioCacheRepository>((
  ref,
) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(minutes: 3),
      sendTimeout: const Duration(seconds: 15),
    ),
  );
  ref.onDispose(() => dio.close(force: true));
  return AurexAudioCacheRepository(
    ref.watch(appDatabaseProvider).db,
    dio,
    ref.watch(appLoggerProvider),
  );
});

class AurexAudioCacheRecord {
  const AurexAudioCacheRecord({
    required this.videoId,
    required this.trackId,
    required this.title,
    required this.artist,
    required this.artworkUrl,
    required this.localFilePath,
    required this.fileSizeBytes,
    required this.createdAt,
    required this.lastUsedAt,
    required this.expiresAt,
    required this.playCount,
  });

  final String videoId;
  final String trackId;
  final String title;
  final String artist;
  final String? artworkUrl;
  final String localFilePath;
  final int fileSizeBytes;
  final DateTime createdAt;
  final DateTime lastUsedAt;
  final DateTime expiresAt;
  final int playCount;

  factory AurexAudioCacheRecord.fromJson(Map<String, dynamic> json) {
    return AurexAudioCacheRecord(
      videoId: json['videoId'] as String,
      trackId: json['trackId'] as String,
      title: json['title'] as String,
      artist: json['artist'] as String,
      artworkUrl: json['artworkUrl'] as String?,
      localFilePath: json['localFilePath'] as String,
      fileSizeBytes: json['fileSizeBytes'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastUsedAt: DateTime.parse(json['lastUsedAt'] as String),
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      playCount: json['playCount'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
    'videoId': videoId,
    'trackId': trackId,
    'title': title,
    'artist': artist,
    'artworkUrl': artworkUrl,
    'localFilePath': localFilePath,
    'fileSizeBytes': fileSizeBytes,
    'createdAt': createdAt.toIso8601String(),
    'lastUsedAt': lastUsedAt.toIso8601String(),
    'expiresAt': expiresAt.toIso8601String(),
    'playCount': playCount,
  };

  AurexAudioCacheRecord copyWith({
    DateTime? lastUsedAt,
    DateTime? expiresAt,
    int? playCount,
  }) {
    return AurexAudioCacheRecord(
      videoId: videoId,
      trackId: trackId,
      title: title,
      artist: artist,
      artworkUrl: artworkUrl,
      localFilePath: localFilePath,
      fileSizeBytes: fileSizeBytes,
      createdAt: createdAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      playCount: playCount ?? this.playCount,
    );
  }
}

class AurexAudioCacheRepository {
  AurexAudioCacheRepository(
    this._database,
    this._dio,
    this._logger, {
    Future<String?> Function()? cacheDirectoryPath,
  }) : _cacheDirectoryPath =
           cacheDirectoryPath ?? AppPaths.aurexAudioCacheDirectoryPath;

  final Database _database;
  final Dio _dio;
  final Logger _logger;
  final Future<String?> Function() _cacheDirectoryPath;
  final Map<String, Future<void>> _activeDownloads = {};

  static const cacheLifetime = Duration(hours: 48);
  static final _store = stringMapStoreFactory.store('aurex_audio_cache');

  Future<AurexAudioCacheRecord?> getRecord(String videoId) async {
    final json = await _store.record(videoId).get(_database);
    if (json == null) {
      return null;
    }
    try {
      return AurexAudioCacheRecord.fromJson(json);
    } on Object {
      await _store.record(videoId).delete(_database);
      return null;
    }
  }

  Future<void> upsert(AurexAudioCacheRecord record) async {
    await _store.record(record.videoId).put(_database, record.toJson());
  }

  Future<Uri?> getCachedUri(Track track) async {
    if (kIsWeb || !track.isAurexSource) {
      return null;
    }
    final videoId = track.aurexVideoId?.trim();
    if (videoId == null || videoId.isEmpty) {
      return null;
    }

    final record = await getRecord(videoId);
    if (record == null) {
      return null;
    }
    final cacheDirectory = await _cacheDirectoryPath();
    if (cacheDirectory == null ||
        !_isInsideCacheDirectory(record.localFilePath, cacheDirectory)) {
      await _store.record(videoId).delete(_database);
      return null;
    }

    final now = DateTime.now();
    final actualSize = await fileLength(record.localFilePath);
    final isInvalid =
        now.isAfter(record.expiresAt) ||
        actualSize == null ||
        actualSize <= 0 ||
        actualSize != record.fileSizeBytes;
    if (isInvalid) {
      await _removeRecordAndFile(record, cacheDirectory);
      return null;
    }

    final updated = record.copyWith(
      lastUsedAt: now,
      expiresAt: now.add(cacheLifetime),
      playCount: record.playCount + 1,
    );
    await upsert(updated);
    return Uri.file(record.localFilePath);
  }

  Future<void> cacheResolvedTrack(Track track, Uri sourceUri) async {
    if (kIsWeb ||
        !track.isAurexSource ||
        (sourceUri.scheme != 'http' && sourceUri.scheme != 'https')) {
      return;
    }
    final videoId = track.aurexVideoId?.trim();
    if (videoId == null || videoId.isEmpty) {
      return;
    }
    final existingDownload = _activeDownloads[videoId];
    if (existingDownload != null) {
      try {
        await existingDownload;
      } on Object {
        // The original cache attempt already records a debug-only diagnostic.
      }
      return;
    }
    final operation = _cacheIfMissing(track, videoId, sourceUri);
    _activeDownloads[videoId] = operation;
    try {
      await operation;
    } on Object catch (error) {
      _logger.d('Aurex audio cache write skipped for $videoId: $error');
    } finally {
      _activeDownloads.remove(videoId);
    }
  }

  Future<void> _cacheIfMissing(
    Track track,
    String videoId,
    Uri sourceUri,
  ) async {
    if (await getCachedUri(track) != null) {
      return;
    }
    await _downloadAndStore(track, videoId, sourceUri);
  }

  Future<void> _downloadAndStore(
    Track track,
    String videoId,
    Uri sourceUri,
  ) async {
    final cacheDirectory = await _cacheDirectoryPath();
    if (cacheDirectory == null) {
      return;
    }
    await ensureDirectory(cacheDirectory);

    final safeVideoId = videoId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    if (safeVideoId.isEmpty) {
      return;
    }
    final targetPath = p.join(cacheDirectory, '$safeVideoId.mp3');
    final partialPath = '$targetPath.part';
    await deleteFileIfExists(partialPath);
    var metadataSaved = false;

    try {
      await _dio.download(sourceUri.toString(), partialPath);
      final partialSize = await fileLength(partialPath);
      if (partialSize == null || partialSize <= 0) {
        throw StateError('Downloaded cache file was empty.');
      }
      await moveFile(partialPath, targetPath);
      final fileSize = await fileLength(targetPath);
      if (fileSize == null || fileSize <= 0) {
        throw StateError('Completed cache file was unavailable.');
      }

      final now = DateTime.now();
      await upsert(
        AurexAudioCacheRecord(
          videoId: videoId,
          trackId: track.id,
          title: track.title,
          artist: track.artistNames,
          artworkUrl: track.artworkUrl,
          localFilePath: targetPath,
          fileSizeBytes: fileSize,
          createdAt: now,
          lastUsedAt: now,
          expiresAt: now.add(cacheLifetime),
          playCount: 1,
        ),
      );
      metadataSaved = true;
    } finally {
      await deleteFileIfExists(partialPath);
      if (!metadataSaved) {
        await deleteFileIfExists(targetPath);
      }
    }
  }

  Future<void> _removeRecordAndFile(
    AurexAudioCacheRecord record,
    String cacheDirectory,
  ) async {
    await _store.record(record.videoId).delete(_database);
    if (_isInsideCacheDirectory(record.localFilePath, cacheDirectory)) {
      await deleteFileIfExists(record.localFilePath);
    }
  }

  bool _isInsideCacheDirectory(String filePath, String cacheDirectory) {
    final normalizedFile = p.normalize(p.absolute(filePath));
    final normalizedDirectory = p.normalize(p.absolute(cacheDirectory));
    return p.isWithin(normalizedDirectory, normalizedFile);
  }
}
