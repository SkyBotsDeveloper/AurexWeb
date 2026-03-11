import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../library/data/library_models.dart';
import '../../library/data/library_repository.dart';
import '../../library/presentation/add_to_playlist_sheet.dart';
import '../../player/data/download_manager.dart';
import '../../player/data/playback_models.dart';
import '../domain/music_models.dart';

final likedTrackIdsStreamProvider = StreamProvider.autoDispose<Set<String>>(
  (ref) => ref.watch(libraryRepositoryProvider).watchLikedIds(),
);

final downloadedTracksStreamProvider =
    StreamProvider.autoDispose<List<DownloadRecord>>(
  (ref) => ref.watch(libraryRepositoryProvider).watchDownloads(),
);

class TrackSupportActions extends ConsumerWidget {
  const TrackSupportActions({super.key, required this.track});

  final Track track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final likedIds = ref.watch(likedTrackIdsStreamProvider);
    final downloads = ref.watch(downloadedTracksStreamProvider);
    final isLiked = likedIds.asData?.value.contains(track.id) ?? false;
    final isDownloaded =
        (downloads.asData?.value ?? const <DownloadRecord>[]).any(
      (item) => item.track.id == track.id,
    );
    final manager = ref.watch(downloadManagerProvider);

    return ValueListenableBuilder<Map<String, DownloadTaskProgress>>(
      valueListenable: manager.progressNotifier,
      builder: (context, progressMap, child) {
        final progress = progressMap[track.id];
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            OutlinedButton.icon(
              onPressed: () => ref.read(libraryRepositoryProvider).toggleLike(track),
              icon: Icon(
                isLiked
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
              ),
              label: Text(isLiked ? 'Liked' : 'Like'),
            ),
            OutlinedButton.icon(
              onPressed: () => showAddToPlaylistSheet(context, ref, track),
              icon: const Icon(Icons.playlist_add_rounded),
              label: const Text('Playlist'),
            ),
            FilledButton.tonalIcon(
              onPressed: () => _handleDownloadAction(
                context,
                ref,
                progress: progress,
                isDownloaded: isDownloaded,
              ),
              icon: Icon(_downloadIcon(progress, isDownloaded)),
              label: Text(_downloadLabel(progress, isDownloaded)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleDownloadAction(
    BuildContext context,
    WidgetRef ref, {
    required DownloadTaskProgress? progress,
    required bool isDownloaded,
  }) async {
    final manager = ref.read(downloadManagerProvider);
    try {
      if (progress?.isRunning ?? false) {
        manager.cancel(track.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Download cancelled')),
          );
        }
        return;
      }

      if (isDownloaded) {
        await manager.deleteDownload(track.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Download removed')),
          );
        }
        return;
      }

      await manager.downloadTrack(track);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Download complete')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    }
  }

  static IconData _downloadIcon(
    DownloadTaskProgress? progress,
    bool isDownloaded,
  ) {
    if (progress?.isRunning ?? false) {
      return Icons.downloading_rounded;
    }
    if (isDownloaded) {
      return Icons.delete_outline_rounded;
    }
    return Icons.download_rounded;
  }

  static String _downloadLabel(
    DownloadTaskProgress? progress,
    bool isDownloaded,
  ) {
    if (progress?.isRunning ?? false) {
      return '${((progress?.progress ?? 0) * 100).round()}%';
    }
    if (isDownloaded) {
      return 'Remove Download';
    }
    return 'Download';
  }
}
