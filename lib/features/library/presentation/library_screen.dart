import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_panel.dart';
import '../../../core/widgets/screen_intro_panel.dart';
import '../../../core/widgets/state_scaffold.dart';
import '../../music/domain/music_models.dart';
import '../../player/data/download_manager.dart';
import '../../player/data/playback_controller.dart';
import '../../rooms/data/room_session_controller.dart';
import '../data/library_models.dart';
import '../data/library_repository.dart';

final likedTracksProvider = StreamProvider<List<Track>>(
  (ref) => ref.watch(libraryRepositoryProvider).watchLikedTracks(),
);
final historyTracksProvider = StreamProvider<List<Track>>(
  (ref) => ref.watch(libraryRepositoryProvider).watchHistory(),
);
final downloadedTracksProvider = StreamProvider<List<DownloadRecord>>(
  (ref) => ref.watch(libraryRepositoryProvider).watchDownloads(),
);
final playlistsProvider = StreamProvider<List<UserPlaylist>>(
  (ref) => ref.watch(libraryRepositoryProvider).watchPlaylists(),
);

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppColors.of(context);
    final controlsLocked = ref
        .watch(roomSessionControllerProvider)
        .controlsLocked;
    final isCompact = MediaQuery.sizeOf(context).width < 600;
    final likedTracks = ref.watch(likedTracksProvider);
    final downloadedTracks = ref.watch(downloadedTracksProvider);
    final historyTracks = ref.watch(historyTracksProvider);
    final playlists = ref.watch(playlistsProvider);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(20, isCompact ? 18 : 16, 20, 0),
                child: Column(
                  children: [
                    ScreenIntroPanel(
                      compact: isCompact,
                      eyebrow: 'Library',
                      title: isCompact
                          ? 'Everything you want to keep close.'
                          : 'Keep saved music, downloads, history, and playlists in one place.',
                      description: isCompact
                          ? 'Liked songs, offline tracks, history, and playlists stay easy to reach.'
                          : 'Move between saved songs, offline playback, listening history, and your own playlists without the layout getting in the way.',
                      trailing: IconButton.filledTonal(
                        onPressed: () => _createPlaylist(context, ref),
                        icon: const Icon(Icons.playlist_add_rounded),
                      ),
                    ),
                    const SizedBox(height: 16),
                    GlassPanel(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final itemWidth = (constraints.maxWidth - 10) / 2;
                              return Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  SizedBox(
                                    width: itemWidth,
                                    child: _MetricChip(
                                      label: 'Liked',
                                      value:
                                          '${likedTracks.asData?.value.length ?? 0}',
                                      icon: Icons.favorite_rounded,
                                    ),
                                  ),
                                  SizedBox(
                                    width: itemWidth,
                                    child: _MetricChip(
                                      label: 'Downloads',
                                      value:
                                          '${downloadedTracks.asData?.value.length ?? 0}',
                                      icon: Icons.download_done_rounded,
                                    ),
                                  ),
                                  SizedBox(
                                    width: itemWidth,
                                    child: _MetricChip(
                                      label: 'History',
                                      value:
                                          '${historyTracks.asData?.value.length ?? 0}',
                                      icon: Icons.history_rounded,
                                    ),
                                  ),
                                  SizedBox(
                                    width: itemWidth,
                                    child: _MetricChip(
                                      label: 'Playlists',
                                      value:
                                          '${playlists.asData?.value.length ?? 0}',
                                      icon: Icons.queue_music_rounded,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          if (controlsLocked) ...[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: palette.surfaceInset,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: palette.border),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.lock_outline_rounded,
                                    color: palette.textSecondary,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Playback is currently controlled by your active room host.',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: palette.surfaceInset,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: palette.border),
                      ),
                      child: TabBar(
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                        dividerColor: Colors.transparent,
                        indicator: BoxDecoration(
                          color: palette.accentSoft,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: palette.border),
                        ),
                        indicatorSize: TabBarIndicatorSize.tab,
                        tabs: const [
                          Tab(
                            height: 58,
                            icon: Icon(Icons.favorite_rounded, size: 18),
                            text: 'Liked',
                          ),
                          Tab(
                            height: 58,
                            icon: Icon(Icons.download_done_rounded, size: 18),
                            text: 'Downloads',
                          ),
                          Tab(
                            height: 58,
                            icon: Icon(Icons.history_rounded, size: 18),
                            text: 'History',
                          ),
                          Tab(
                            height: 58,
                            icon: Icon(Icons.queue_music_rounded, size: 18),
                            text: 'Playlists',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: TabBarView(
                  children: [
                    _TrackList(
                      asyncTracks: likedTracks,
                      controlsLocked: controlsLocked,
                      showLikeButton: true,
                      emptyTitle: 'No liked songs yet',
                      emptyMessage:
                          'Tap the heart on any track to keep it close.',
                    ),
                    _DownloadList(
                      asyncDownloads: downloadedTracks,
                      controlsLocked: controlsLocked,
                    ),
                    _TrackList(
                      asyncTracks: historyTracks,
                      controlsLocked: controlsLocked,
                      emptyTitle: 'No listening history yet',
                      emptyMessage:
                          'Start playing songs and your recent listens will land here.',
                    ),
                    _PlaylistList(asyncPlaylists: playlists),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createPlaylist(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Playlist'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Late Night Rotation'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (result != null && result.isNotEmpty) {
      await ref.read(libraryRepositoryProvider).createPlaylist(result);
    }
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 84),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: palette.surfaceInset,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: palette.accent),
              const Spacer(),
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontSize: 28),
          ),
        ],
      ),
    );
  }
}

class _TrackList extends ConsumerWidget {
  const _TrackList({
    required this.asyncTracks,
    required this.controlsLocked,
    this.showLikeButton = false,
    required this.emptyTitle,
    required this.emptyMessage,
  });

  final AsyncValue<List<Track>> asyncTracks;
  final bool controlsLocked;
  final bool showLikeButton;
  final String emptyTitle;
  final String emptyMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return asyncTracks.when(
      data: (tracks) {
        if (tracks.isEmpty) {
          return _LibraryEmptyState(
            icon: Icons.library_music_outlined,
            title: emptyTitle,
            message: emptyMessage,
            actionLabel: 'Explore music',
            onAction: () => context.go('/home'),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          itemCount: tracks.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final track = tracks[index];
            return _TrackTileCard(
              track: track,
              controlsLocked: controlsLocked,
              trailing: showLikeButton
                  ? IconButton(
                      onPressed: () =>
                          ref.read(libraryRepositoryProvider).toggleLike(track),
                      icon: const Icon(Icons.favorite_rounded),
                    )
                  : null,
              onTap: controlsLocked
                  ? null
                  : () => ref.read(playbackControllerProvider).playTrack(track),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => StateScaffold(
        icon: Icons.error_outline_rounded,
        title: 'Library error',
        message: error.toString(),
      ),
    );
  }
}

class _DownloadList extends ConsumerWidget {
  const _DownloadList({
    required this.asyncDownloads,
    required this.controlsLocked,
  });

  final AsyncValue<List<DownloadRecord>> asyncDownloads;
  final bool controlsLocked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return asyncDownloads.when(
      data: (downloads) {
        if (downloads.isEmpty) {
          return _LibraryEmptyState(
            icon: Icons.download_outlined,
            title: 'No downloads yet',
            message: 'Downloaded tracks will appear here for offline playback.',
            actionLabel: 'Browse songs',
            onAction: () => context.go('/search'),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          itemCount: downloads.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final download = downloads[index];
            return _TrackTileCard(
              track: download.track,
              controlsLocked: controlsLocked,
              trailing: IconButton(
                onPressed: () => ref
                    .read(downloadManagerProvider)
                    .deleteDownload(download.track.id),
                icon: const Icon(Icons.delete_outline_rounded),
              ),
              badge: 'Offline',
              onTap: controlsLocked
                  ? null
                  : () => ref
                        .read(playbackControllerProvider)
                        .playTrack(download.track),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => StateScaffold(
        icon: Icons.error_outline_rounded,
        title: 'Downloads error',
        message: error.toString(),
      ),
    );
  }
}

class _PlaylistList extends StatelessWidget {
  const _PlaylistList({required this.asyncPlaylists});

  final AsyncValue<List<UserPlaylist>> asyncPlaylists;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return asyncPlaylists.when(
      data: (playlists) {
        if (playlists.isEmpty) {
          return const _LibraryEmptyState(
            icon: Icons.playlist_play_rounded,
            title: 'No playlists yet',
            message:
                'Create a playlist from the Library tab to start organizing tracks.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          itemCount: playlists.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final playlist = playlists[index];
            return GlassPanel(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: palette.accentSoft,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.queue_music_rounded,
                      color: palette.accent,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          playlist.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${playlist.tracks.length} tracks',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => StateScaffold(
        icon: Icons.error_outline_rounded,
        title: 'Playlists error',
        message: error.toString(),
      ),
    );
  }
}

class _LibraryEmptyState extends StatelessWidget {
  const _LibraryEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        GlassPanel(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: palette.accentSoft,
                  border: Border.all(color: palette.border),
                ),
                child: Icon(icon, color: palette.accent, size: 30),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 18),
                FilledButton.tonal(
                  onPressed: onAction,
                  child: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _TrackTileCard extends StatelessWidget {
  const _TrackTileCard({
    required this.track,
    required this.controlsLocked,
    required this.onTap,
    this.trailing,
    this.badge,
  });

  final Track track;
  final bool controlsLocked;
  final VoidCallback? onTap;
  final Widget? trailing;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            gradient: palette.tileGradient,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: palette.border),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: palette.surfaceBright,
                ),
                clipBehavior: Clip.antiAlias,
                child: track.artworkUrl == null
                    ? Icon(Icons.music_note_rounded, color: palette.accent)
                    : Image.network(track.artworkUrl!, fit: BoxFit.cover),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: palette.accentSoft,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              badge!,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: palette.accent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      track.artistNames,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      controlsLocked
                          ? 'Host-controlled playback is active'
                          : track.albumName ?? 'Ready to play',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: controlsLocked
                            ? palette.warning
                            : palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              trailing ??
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: controlsLocked
                          ? palette.surfaceInset
                          : palette.accentSoft,
                    ),
                    child: Icon(
                      controlsLocked
                          ? Icons.lock_outline_rounded
                          : Icons.play_arrow_rounded,
                      color: controlsLocked
                          ? palette.textSecondary
                          : palette.accent,
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
