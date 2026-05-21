import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:collection/collection.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/glass_panel.dart';
import '../../../core/widgets/network_artwork.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../../core/widgets/state_scaffold.dart';
import '../../player/data/playback_controller.dart';
import '../../rooms/data/room_session_controller.dart';
import '../../music/domain/music_models.dart';
import '../data/library_models.dart';
import '../data/library_repository.dart';

final userPlaylistProvider = StreamProvider.family<UserPlaylist?, String>((
  ref,
  playlistId,
) {
  return ref.watch(libraryRepositoryProvider).watchPlaylist(playlistId);
});

class UserPlaylistDetailScreen extends ConsumerWidget {
  const UserPlaylistDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlist = ref.watch(userPlaylistProvider(id));
    final palette = AppColors.of(context);
    final roomSession = ref.watch(roomSessionControllerProvider);
    final bottomPadding = MediaQuery.sizeOf(context).width >= 1120
        ? 32.0
        : 140.0;

    return Scaffold(
      appBar: AppBar(title: const Text('Playlist')),
      body: playlist.when(
        loading: () =>
            const MediaDetailSkeleton(rowCount: 5, showDescription: false),
        error: (error, _) => StateScaffold(
          icon: Icons.error_outline_rounded,
          title: 'Unable to open playlist',
          message: friendlyErrorMessage(error),
        ),
        data: (playlist) {
          if (playlist == null) {
            return const StateScaffold(
              icon: Icons.playlist_remove_rounded,
              title: 'Playlist not found',
              message: 'This playlist is no longer available in your library.',
            );
          }

          final tracks = playlist.tracks;
          final totalDuration = tracks.fold<Duration>(
            Duration.zero,
            (total, track) => total + (track.duration ?? Duration.zero),
          );
          final metadata = [
            '${tracks.length} ${tracks.length == 1 ? 'track' : 'tracks'}',
            if (tracks.isNotEmpty) formatDuration(totalDuration),
          ].join(' / ');

          return ListView(
            padding: EdgeInsets.fromLTRB(20, 20, 20, bottomPadding),
            children: [
              GlassPanel(
                padding: const EdgeInsets.all(18),
                child: Wrap(
                  spacing: 18,
                  runSpacing: 18,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _PlaylistArtwork(playlist: playlist),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: palette.accentSoft,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Your Playlist',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: palette.accent,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            playlist.name,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            metadata,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          if (roomSession.controlsLocked) ...[
                            const SizedBox(height: 10),
                            Text(
                              roomPlaybackLockedMessage(roomSession),
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: palette.warning),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              FilledButton.icon(
                                onPressed:
                                    tracks.isEmpty || roomSession.controlsLocked
                                    ? null
                                    : () async {
                                        await ref
                                            .read(playbackControllerProvider)
                                            .setQueue(tracks);
                                        if (context.mounted) {
                                          context.push('/player');
                                        }
                                      },
                                icon: const Icon(Icons.play_arrow_rounded),
                                label: const Text('Play Playlist'),
                              ),
                              OutlinedButton.icon(
                                onPressed:
                                    tracks.isEmpty || roomSession.controlsLocked
                                    ? null
                                    : () async {
                                        await ref
                                            .read(playbackControllerProvider)
                                            .setQueue(tracks, autoplay: false);
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text('Playlist loaded'),
                                            ),
                                          );
                                        }
                                      },
                                icon: const Icon(Icons.queue_music_rounded),
                                label: const Text('Load Queue'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              if (tracks.isEmpty)
                const StateScaffold(
                  icon: Icons.playlist_add_rounded,
                  title: 'No songs yet',
                  message:
                      'Open any song and use the Playlist action to add tracks here.',
                )
              else
                GlassPanel(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tracks',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 14),
                      for (final entry in tracks.asMap().entries) ...[
                        _PlaylistTrackTile(
                          track: entry.value,
                          index: entry.key,
                          tracks: tracks,
                          controlsLocked: roomSession.controlsLocked,
                        ),
                        if (entry.key < tracks.length - 1)
                          Divider(
                            color: palette.border.withAlpha(120),
                            height: 18,
                          ),
                      ],
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _PlaylistArtwork extends StatelessWidget {
  const _PlaylistArtwork({required this.playlist});

  final UserPlaylist playlist;

  @override
  Widget build(BuildContext context) {
    final firstArtwork = playlist.tracks
        .map((track) => track.artworkUrl)
        .whereType<String>()
        .firstOrNull;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        width: 144,
        height: 144,
        child: NetworkArtwork(
          imageUrl: firstArtwork,
          fallbackIcon: Icons.queue_music_rounded,
          iconSize: 42,
        ),
      ),
    );
  }
}

class _PlaylistTrackTile extends ConsumerWidget {
  const _PlaylistTrackTile({
    required this.track,
    required this.index,
    required this.tracks,
    required this.controlsLocked,
  });

  final Track track;
  final int index;
  final List<Track> tracks;
  final bool controlsLocked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 48,
          height: 48,
          child: NetworkArtwork(
            imageUrl: track.artworkUrl,
            fallbackIcon: Icons.music_note_rounded,
            iconSize: 26,
          ),
        ),
      ),
      title: Text(track.title),
      subtitle: Text(
        '${track.artistNames} / ${formatDuration(track.duration)}',
      ),
      trailing: Icon(
        controlsLocked ? Icons.lock_outline_rounded : Icons.play_arrow_rounded,
      ),
      onTap: controlsLocked
          ? null
          : () async {
              await ref
                  .read(playbackControllerProvider)
                  .setQueue(tracks, initialIndex: index);
              if (context.mounted) {
                context.push('/player');
              }
            },
    );
  }
}
