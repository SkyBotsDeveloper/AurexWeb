import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/widgets/app_shell_scope.dart';
import '../../../core/widgets/glass_panel.dart';
import '../../../core/widgets/network_artwork.dart';
import '../../../core/widgets/screen_intro_panel.dart';
import '../../../core/widgets/skeleton_loader.dart';
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
    final likedTracks = ref.watch(likedTracksProvider);
    final downloadedTracks = ref.watch(downloadedTracksProvider);
    final historyTracks = ref.watch(historyTracksProvider);
    final playlists = ref.watch(playlistsProvider);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wideLayout = constraints.maxWidth >= 980;
              final narrowLayout = constraints.maxWidth < 720;
              final shortLayout = constraints.maxHeight < 860;
              final denseLayout =
                  constraints.maxWidth < 430 || constraints.maxHeight < 760;
              final introCompact = narrowLayout || shortLayout;
              final sectionGap = wideLayout
                  ? (shortLayout ? 12.0 : 16.0)
                  : (denseLayout ? 4.0 : 12.0);

              return Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      narrowLayout ? 16 : 20,
                      denseLayout ? 6 : (introCompact ? 16 : 18),
                      narrowLayout ? 16 : 20,
                      0,
                    ),
                    child: Column(
                      children: [
                        if (wideLayout)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 7,
                                child: ScreenIntroPanel(
                                  compact: true,
                                  eyebrow: 'Library',
                                  title:
                                      'Keep saved music, downloads, history, and playlists in one place.',
                                  description:
                                      'Move between saved songs, offline playback, listening history, and your own playlists without losing view space.',
                                  trailing: IconButton.filledTonal(
                                    onPressed: () =>
                                        _createPlaylist(context, ref),
                                    icon: const Icon(
                                      Icons.playlist_add_rounded,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 6,
                                child: _LibraryOverviewPanel(
                                  likedCount:
                                      likedTracks.asData?.value.length ?? 0,
                                  downloadCount:
                                      downloadedTracks.asData?.value.length ??
                                      0,
                                  historyCount:
                                      historyTracks.asData?.value.length ?? 0,
                                  playlistCount:
                                      playlists.asData?.value.length ?? 0,
                                  controlsLocked: controlsLocked,
                                ),
                              ),
                            ],
                          )
                        else if (narrowLayout) ...[
                          _LibraryCompactHeader(
                            dense: denseLayout,
                            onCreatePlaylist: () =>
                                _createPlaylist(context, ref),
                          ),
                          SizedBox(height: sectionGap),
                          _LibraryOverviewPanel(
                            likedCount: likedTracks.asData?.value.length ?? 0,
                            downloadCount:
                                downloadedTracks.asData?.value.length ?? 0,
                            historyCount:
                                historyTracks.asData?.value.length ?? 0,
                            playlistCount: playlists.asData?.value.length ?? 0,
                            controlsLocked: controlsLocked,
                            compact: true,
                            dense: denseLayout,
                          ),
                        ] else ...[
                          ScreenIntroPanel(
                            compact: introCompact,
                            eyebrow: 'Library',
                            title: 'Everything you want to keep close.',
                            description:
                                'Liked songs, offline tracks, history, and playlists stay easy to reach.',
                            trailing: IconButton.filledTonal(
                              onPressed: () => _createPlaylist(context, ref),
                              icon: const Icon(Icons.playlist_add_rounded),
                            ),
                          ),
                          SizedBox(height: sectionGap),
                          _LibraryOverviewPanel(
                            likedCount: likedTracks.asData?.value.length ?? 0,
                            downloadCount:
                                downloadedTracks.asData?.value.length ?? 0,
                            historyCount:
                                historyTracks.asData?.value.length ?? 0,
                            playlistCount: playlists.asData?.value.length ?? 0,
                            controlsLocked: controlsLocked,
                            compact: false,
                            dense: false,
                          ),
                        ],
                        SizedBox(height: sectionGap),
                        _LibraryTabs(
                          palette: palette,
                          wideLayout: wideLayout,
                          compact: introCompact,
                          narrow: narrowLayout,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: shortLayout ? 10 : 14),
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
              );
            },
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

class _LibraryOverviewPanel extends StatelessWidget {
  const _LibraryOverviewPanel({
    required this.likedCount,
    required this.downloadCount,
    required this.historyCount,
    required this.playlistCount,
    required this.controlsLocked,
    this.compact = false,
    this.dense = false,
  });

  final int likedCount;
  final int downloadCount;
  final int historyCount;
  final int playlistCount;
  final bool controlsLocked;
  final bool compact;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);

    if (compact) {
      final metricEntries = [
        ('Liked', '$likedCount', Icons.favorite_rounded),
        ('Downloads', '$downloadCount', Icons.download_done_rounded),
        ('History', '$historyCount', Icons.history_rounded),
        ('Playlists', '$playlistCount', Icons.queue_music_rounded),
      ];

      return GlassPanel(
        padding: EdgeInsets.all(dense ? 6 : 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final spacing = dense ? 4.0 : 10.0;
                final itemWidth = (constraints.maxWidth - spacing) / 2;
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    for (final entry in metricEntries)
                      SizedBox(
                        width: itemWidth,
                        child: _MetricChip(
                          label: entry.$1,
                          value: entry.$2,
                          icon: entry.$3,
                          compact: true,
                          dense: dense,
                        ),
                      ),
                  ],
                );
              },
            ),
            if (controlsLocked) ...[
              SizedBox(height: dense ? 3 : 8),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: dense ? 7 : 12,
                  vertical: dense ? 6 : 10,
                ),
                decoration: BoxDecoration(
                  color: palette.surfaceInset,
                  borderRadius: BorderRadius.circular(dense ? 12 : 16),
                  border: Border.all(color: palette.border),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: dense ? 15 : 18,
                      color: palette.textSecondary,
                    ),
                    SizedBox(width: dense ? 5 : 8),
                    Expanded(
                      child: Text(
                        'Room host is controlling playback right now.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: dense ? 10.5 : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    }

    return GlassPanel(
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
                      value: '$likedCount',
                      icon: Icons.favorite_rounded,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _MetricChip(
                      label: 'Downloads',
                      value: '$downloadCount',
                      icon: Icons.download_done_rounded,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _MetricChip(
                      label: 'History',
                      value: '$historyCount',
                      icon: Icons.history_rounded,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _MetricChip(
                      label: 'Playlists',
                      value: '$playlistCount',
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
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LibraryTabs extends StatelessWidget {
  const _LibraryTabs({
    required this.palette,
    required this.wideLayout,
    required this.compact,
    required this.narrow,
  });

  final AurexPalette palette;
  final bool wideLayout;
  final bool compact;
  final bool narrow;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(narrow ? 4 : 8),
      decoration: BoxDecoration(
        color: palette.surfaceInset,
        borderRadius: BorderRadius.circular(narrow ? 18 : 22),
        border: Border.all(color: palette.border),
      ),
      child: TabBar(
        isScrollable: narrow ? false : !wideLayout,
        tabAlignment: (wideLayout || narrow) ? null : TabAlignment.start,
        labelPadding: EdgeInsets.symmetric(
          horizontal: narrow ? 0 : (wideLayout ? 4 : 6),
        ),
        labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w700,
          fontSize: narrow ? 12 : 14,
        ),
        unselectedLabelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: narrow ? 12 : 14,
        ),
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          color: palette.accentSoft,
          borderRadius: BorderRadius.circular(narrow ? 12 : 16),
          border: Border.all(color: palette.border),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        tabs: [
          Tab(
            height: narrow ? 40 : (compact ? 54 : 58),
            icon: Icon(Icons.favorite_rounded, size: narrow ? 16 : 18),
            text: 'Liked',
          ),
          Tab(
            height: narrow ? 40 : (compact ? 54 : 58),
            icon: Icon(Icons.download_done_rounded, size: narrow ? 16 : 18),
            text: 'Downloads',
          ),
          Tab(
            height: narrow ? 40 : (compact ? 54 : 58),
            icon: Icon(Icons.history_rounded, size: narrow ? 16 : 18),
            text: 'History',
          ),
          Tab(
            height: narrow ? 40 : (compact ? 54 : 58),
            icon: Icon(Icons.queue_music_rounded, size: narrow ? 16 : 18),
            text: 'Playlists',
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.label,
    required this.value,
    required this.icon,
    this.compact = false,
    this.dense = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool compact;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return Container(
      constraints: BoxConstraints(minHeight: compact ? (dense ? 54 : 72) : 84),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? (dense ? 8 : 12) : 14,
        vertical: compact ? (dense ? 6 : 12) : 14,
      ),
      decoration: BoxDecoration(
        color: palette.surfaceInset,
        borderRadius: BorderRadius.circular(compact && dense ? 14 : 18),
        border: Border.all(color: palette.border),
      ),
      child: compact
          ? Row(
              children: [
                Icon(icon, size: dense ? 14 : 18, color: palette.accent),
                SizedBox(width: dense ? 6 : 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        value,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontSize: dense ? 16 : 24, height: 1),
                      ),
                      SizedBox(height: dense ? 0 : 2),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: dense ? 10 : null,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 18, color: palette.accent),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: compact ? 10 : 14),
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontSize: compact ? 24 : 28,
                  ),
                ),
              ],
            ),
    );
  }
}

class _TrackList extends ConsumerStatefulWidget {
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
  ConsumerState<_TrackList> createState() => _TrackListState();
}

mixin _TrackPlaybackLoadingState<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  String? _loadingTrackId;
  bool _loadingTrackWasCurrent = false;
  Duration? _loadingTrackStartPosition;
  late final PlaybackController _playbackController;

  @override
  void initState() {
    super.initState();
    _playbackController = ref.read(playbackControllerProvider);
    _playbackController.notifier.addListener(_handlePlaybackChanged);
  }

  @override
  void dispose() {
    _playbackController.notifier.removeListener(_handlePlaybackChanged);
    super.dispose();
  }

  bool isLoadingTrack(Track track) => _loadingTrackId == track.id;

  Future<void> playTrackWithLoading(Track track) async {
    if (_loadingTrackId == track.id) {
      return;
    }

    final snapshot = _playbackController.snapshot;
    setState(() {
      _loadingTrackId = track.id;
      _loadingTrackWasCurrent = snapshot.currentTrack?.id == track.id;
      _loadingTrackStartPosition = snapshot.position;
    });

    try {
      await _playbackController
          .playTrack(track)
          .timeout(const Duration(seconds: 15), onTimeout: () {});
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            friendlyErrorMessage(
              error,
              fallback: 'Could not load this song. Please try again.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted && _loadingTrackId == track.id) {
        _clearTrackLoading();
      }
    }
  }

  void _handlePlaybackChanged() {
    final loadingTrackId = _loadingTrackId;
    if (!mounted || loadingTrackId == null) {
      return;
    }

    final snapshot = _playbackController.snapshot;
    if (snapshot.error != null) {
      _clearTrackLoading();
      return;
    }
    if (snapshot.currentTrack?.id != loadingTrackId) {
      return;
    }

    final startPosition = _loadingTrackStartPosition;
    final restartedFromBeginning =
        startPosition != null &&
        snapshot.position + const Duration(seconds: 1) < startPosition;
    if (!_loadingTrackWasCurrent || restartedFromBeginning) {
      _clearTrackLoading();
    }
  }

  void _clearTrackLoading() {
    if (!mounted) {
      return;
    }
    setState(() {
      _loadingTrackId = null;
      _loadingTrackWasCurrent = false;
      _loadingTrackStartPosition = null;
    });
  }
}

class _TrackListState extends ConsumerState<_TrackList>
    with _TrackPlaybackLoadingState<_TrackList> {
  @override
  Widget build(BuildContext context) {
    final asyncTracks = widget.asyncTracks;
    final controlsLocked = widget.controlsLocked;
    final showLikeButton = widget.showLikeButton;
    final emptyTitle = widget.emptyTitle;
    final emptyMessage = widget.emptyMessage;

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
          padding: _libraryContentPadding(context),
          itemCount: tracks.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final track = tracks[index];
            final isLoading = isLoadingTrack(track);
            return _TrackTileCard(
              track: track,
              controlsLocked: controlsLocked,
              isLoading: isLoading,
              trailing: showLikeButton
                  ? IconButton(
                      onPressed: isLoading
                          ? null
                          : () => ref
                                .read(libraryRepositoryProvider)
                                .toggleLike(track),
                      icon: const Icon(Icons.favorite_rounded),
                    )
                  : null,
              onTap: controlsLocked || isLoading
                  ? null
                  : () => playTrackWithLoading(track),
            );
          },
        );
      },
      loading: () => ListView(
        padding: _libraryContentPadding(context),
        children: const [ResultsListSkeleton(groupCount: 1, rowCount: 5)],
      ),
      error: (error, _) => StateScaffold(
        icon: Icons.error_outline_rounded,
        title: 'Library error',
        message: friendlyErrorMessage(error),
      ),
    );
  }
}

class _DownloadList extends ConsumerStatefulWidget {
  const _DownloadList({
    required this.asyncDownloads,
    required this.controlsLocked,
  });

  final AsyncValue<List<DownloadRecord>> asyncDownloads;
  final bool controlsLocked;

  @override
  ConsumerState<_DownloadList> createState() => _DownloadListState();
}

class _DownloadListState extends ConsumerState<_DownloadList>
    with _TrackPlaybackLoadingState<_DownloadList> {
  @override
  Widget build(BuildContext context) {
    final asyncDownloads = widget.asyncDownloads;
    final controlsLocked = widget.controlsLocked;

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
          padding: _libraryContentPadding(context),
          itemCount: downloads.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final download = downloads[index];
            final isLoading = isLoadingTrack(download.track);
            return _TrackTileCard(
              track: download.track,
              controlsLocked: controlsLocked,
              isLoading: isLoading,
              trailing: IconButton(
                onPressed: isLoading
                    ? null
                    : () => ref
                          .read(downloadManagerProvider)
                          .deleteDownload(download.track.id),
                icon: const Icon(Icons.delete_outline_rounded),
              ),
              badge: 'Offline',
              onTap: controlsLocked || isLoading
                  ? null
                  : () => playTrackWithLoading(download.track),
            );
          },
        );
      },
      loading: () => ListView(
        padding: _libraryContentPadding(context),
        children: const [ResultsListSkeleton(groupCount: 1, rowCount: 5)],
      ),
      error: (error, _) => StateScaffold(
        icon: Icons.error_outline_rounded,
        title: 'Downloads error',
        message: friendlyErrorMessage(error),
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
          padding: _libraryContentPadding(context),
          itemCount: playlists.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final playlist = playlists[index];
            return GlassPanel(
              padding: const EdgeInsets.all(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => context.push(
                  '/library/playlist/${Uri.encodeComponent(playlist.id)}',
                ),
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
              ),
            );
          },
        );
      },
      loading: () => ListView(
        padding: _libraryContentPadding(context),
        children: const [ResultsListSkeleton(groupCount: 1, rowCount: 5)],
      ),
      error: (error, _) => StateScaffold(
        icon: Icons.error_outline_rounded,
        title: 'Playlists error',
        message: friendlyErrorMessage(error),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            MediaQuery.sizeOf(context).width < 430 ||
            constraints.maxHeight < 360;

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            compact ? 16 : 20,
            compact ? 8 : 12,
            compact ? 16 : 20,
            AppShellScope.bottomInsetOf(context),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: compact
                  ? 0
                  : (constraints.maxHeight - 36).clamp(0, double.infinity),
            ),
            child: Align(
              alignment: compact ? Alignment.topCenter : Alignment.center,
              child: GlassPanel(
                padding: EdgeInsets.all(compact ? 18 : 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: compact ? 60 : 72,
                      height: compact ? 60 : 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: palette.accentSoft,
                        border: Border.all(color: palette.border),
                      ),
                      child: Icon(
                        icon,
                        color: palette.accent,
                        size: compact ? 26 : 30,
                      ),
                    ),
                    SizedBox(height: compact ? 14 : 16),
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
            ),
          ),
        );
      },
    );
  }
}

class _LibraryCompactHeader extends StatelessWidget {
  const _LibraryCompactHeader({
    required this.dense,
    required this.onCreatePlaylist,
  });

  final bool dense;
  final VoidCallback onCreatePlaylist;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GlassPanel(
      padding: EdgeInsets.all(dense ? 6 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: dense ? 7 : 10,
                  vertical: dense ? 4 : 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.of(context).accentSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Library',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: dense ? 11 : null,
                    fontWeight: FontWeight.w700,
                    color: AppColors.of(context).accent,
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(width: dense ? 6 : 10),
              IconButton.filledTonal(
                onPressed: onCreatePlaylist,
                icon: const Icon(Icons.playlist_add_rounded),
                iconSize: dense ? 17 : 22,
                visualDensity: VisualDensity.compact,
                constraints: BoxConstraints.tightFor(
                  width: dense ? 32 : 42,
                  height: dense ? 32 : 42,
                ),
              ),
            ],
          ),
          SizedBox(height: dense ? 4 : 12),
          Text(
            'Everything you want to keep close.',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontSize: dense ? 17 : 26,
              height: dense ? 1.0 : 1.04,
            ),
          ),
          SizedBox(height: dense ? 1 : 6),
          Text(
            'Liked songs, offline tracks, history, and playlists stay easy to reach.',
            style:
                (dense ? theme.textTheme.bodySmall : theme.textTheme.bodyMedium)
                    ?.copyWith(fontSize: dense ? 11 : null, height: 1.15),
          ),
        ],
      ),
    );
  }
}

EdgeInsets _libraryContentPadding(BuildContext context) {
  final compact = MediaQuery.sizeOf(context).width < 600;
  return EdgeInsets.fromLTRB(
    compact ? 16 : 20,
    compact ? 8 : 0,
    compact ? 16 : 20,
    AppShellScope.bottomInsetOf(context),
  );
}

class _TrackTileCard extends StatelessWidget {
  const _TrackTileCard({
    required this.track,
    required this.controlsLocked,
    required this.onTap,
    this.isLoading = false,
    this.trailing,
    this.badge,
  });

  final Track track;
  final bool controlsLocked;
  final VoidCallback? onTap;
  final bool isLoading;
  final Widget? trailing;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: isLoading ? null : onTap,
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
                child: NetworkArtwork(
                  imageUrl: track.artworkUrl,
                  cleanArtworkQuery: track.title,
                  cleanArtworkType: 'song',
                  cleanArtworkSubtitle: track.artistNames,
                  fallbackIcon: Icons.music_note_rounded,
                  iconSize: 30,
                ),
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
                      isLoading
                          ? 'Loading song...'
                          : controlsLocked
                          ? 'Host-controlled playback is active'
                          : track.albumName ?? 'Ready to play',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isLoading
                            ? palette.accent
                            : controlsLocked
                            ? palette.warning
                            : palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (isLoading)
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: palette.accentSoft,
                  ),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.3,
                      color: palette.accent,
                    ),
                  ),
                )
              else
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
