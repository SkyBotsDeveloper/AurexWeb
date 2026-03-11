import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/network/api_client.dart';
import '../../../core/storage/app_paths.dart';
import '../../../core/storage/file_ops.dart';
import '../../library/data/library_models.dart';
import '../../library/data/library_repository.dart';
import '../../music/domain/music_models.dart';
import '../../settings/data/settings_repository.dart';
import 'playback_models.dart';

final downloadManagerProvider = Provider<DownloadManager>((ref) {
  final manager = DownloadManager(
    ref.watch(apiClientProvider),
    ref.watch(libraryRepositoryProvider),
    ref.watch(settingsRepositoryProvider),
  );
  ref.onDispose(manager.dispose);
  return manager;
});

class DownloadManager {
  DownloadManager(this._dio, this._libraryRepository, this._settingsRepository);

  final Dio _dio;
  final LibraryRepository _libraryRepository;
  final SettingsRepository _settingsRepository;

  final ValueNotifier<Map<String, DownloadTaskProgress>> progressNotifier =
      ValueNotifier(<String, DownloadTaskProgress>{});
  final Map<String, CancelToken> _tokens = <String, CancelToken>{};

  Future<void> downloadTrack(
    Track track, {
    AudioQuality? qualityOverride,
  }) async {
    if (kIsWeb) {
      throw UnsupportedError('Offline downloads are not supported on web.');
    }

    final downloadsDir = await AppPaths.downloadsDirectoryPath();
    if (downloadsDir == null) {
      throw StateError('Downloads directory is unavailable.');
    }
    await ensureDirectory(downloadsDir);

    final preferredQuality = qualityOverride ??
        (_settingsRepository.current.autoQuality
            ? AudioQuality.kbps160
            : _settingsRepository.current.downloadQuality);
    final quality = preferredQuality == AudioQuality.auto
        ? AudioQuality.kbps160
        : preferredQuality;

    final url = track.bestAudioUrl(quality);
    if (url == null) {
      throw StateError('No download URL is available for this track.');
    }

    final extension = _inferExtension(url);
    final targetPath = p.join(
      downloadsDir,
      '${track.id}_${quality.key}.$extension',
    );
    final tempPath = '$targetPath.part';

    final cancelToken = CancelToken();
    _tokens[track.id] = cancelToken;
    _setProgress(track.id, 0, true);

    try {
      await deleteFileIfExists(tempPath);
      await _dio.download(
        url,
        tempPath,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          final progress = total <= 0 ? 0.0 : received / total;
          _setProgress(track.id, progress.clamp(0, 1).toDouble(), true);
        },
      );
      await moveFile(tempPath, targetPath);
      final size = await fileLength(targetPath);
      await _libraryRepository.upsertDownload(
        DownloadRecord(
          track: track,
          localPath: targetPath,
          quality: quality,
          downloadedAt: DateTime.now(),
          fileSizeBytes: size,
        ),
      );
      _setProgress(track.id, 1, false);
    } on DioException catch (error) {
      final message = CancelToken.isCancel(error)
          ? 'Download cancelled'
          : (error.message ?? 'Download failed');
      _setProgress(track.id, 0, false, message);
      rethrow;
    } finally {
      _tokens.remove(track.id);
      unawaited(deleteFileIfExists(tempPath));
    }
  }

  Future<void> deleteDownload(String trackId) async {
    final record = await _libraryRepository.getDownload(trackId);
    if (record != null) {
      await deleteFileIfExists(record.localPath);
      await _libraryRepository.removeDownload(trackId);
    }
  }

  Future<void> clearDownloads() async {
    final records = await _libraryRepository.watchDownloads().first;
    for (final record in records) {
      await deleteDownload(record.track.id);
    }
    final downloadsDir = await AppPaths.downloadsDirectoryPath();
    if (downloadsDir != null) {
      await deleteDirectoryContents(downloadsDir);
    }
  }

  void cancel(String trackId) {
    _tokens[trackId]?.cancel();
    _tokens.remove(trackId);
  }

  void dispose() {
    for (final token in _tokens.values) {
      token.cancel();
    }
    progressNotifier.dispose();
  }

  void _setProgress(
    String trackId,
    double progress,
    bool isRunning, [
    String? error,
  ]) {
    progressNotifier.value = {
      ...progressNotifier.value,
      trackId: DownloadTaskProgress(
        trackId: trackId,
        progress: progress,
        isRunning: isRunning,
        error: error,
      ),
    };
  }

  String _inferExtension(String url) {
    final path = Uri.parse(url).path;
    final extension = p.extension(path).replaceFirst('.', '');
    return extension.isEmpty ? 'm4a' : extension;
  }
}
