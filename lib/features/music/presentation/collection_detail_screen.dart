import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/glass_panel.dart';
import '../../../core/widgets/network_artwork.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../../core/widgets/state_scaffold.dart';
import '../../player/data/playback_controller.dart';
import '../../rooms/data/room_session_controller.dart';
import '../data/music_repository.dart';
import '../domain/music_models.dart';

enum CollectionKind { album, playlist }

class CollectionDetailScreen extends ConsumerWidget {
  const CollectionDetailScreen({
    super.key,
    required this.id,
    required this.kind,
  });

  final String id;
  final CollectionKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppColors.of(context);
    final roomSession = ref.watch(roomSessionControllerProvider);
    final bottomPadding = MediaQuery.sizeOf(context).width >= 1120
        ? 32.0
        : 140.0;
    final future = kind == CollectionKind.album
        ? ref.read(musicRepositoryProvider).fetchAlbum(id)
        : ref.read(musicRepositoryProvider).fetchPlaylist(id);

    return Scaffold(
      appBar: AppBar(
        title: Text(kind == CollectionKind.album ? 'Album' : 'Playlist'),
      ),
      body: FutureBuilder<CollectionDetail>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return MediaDetailSkeleton(
              showDescription: kind == CollectionKind.playlist,
              rowCount: 7,
            );
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return StateScaffold(
              icon: Icons.error_outline_rounded,
              title: 'Unable to load details',
              message: snapshot.error.toString(),
            );
          }

          final detail = snapshot.data!;
          final metadata = [
            if (detail.artists.isNotEmpty)
              detail.artists.map((artist) => artist.name).join(', '),
            if (detail.songCount != null) '${detail.songCount} songs',
            if (detail.year != null) detail.year!,
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
                    _DetailArtwork(
                      artworkUrl: detail.artworkUrl,
                      fallbackIcon: kind == CollectionKind.album
                          ? Icons.album_rounded
                          : Icons.queue_music_rounded,
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
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
                              kind == CollectionKind.album
                                  ? 'Album'
                                  : 'Playlist',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: palette.accent,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            detail.title,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          if (metadata.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              metadata,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ],
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
                                    detail.songs.isEmpty ||
                                        roomSession.controlsLocked
                                    ? null
                                    : () async {
                                        await ref
                                            .read(playbackControllerProvider)
                                            .setQueue(detail.songs);
                                        if (context.mounted) {
                                          context.push('/player');
                                        }
                                      },
                                icon: const Icon(Icons.play_arrow_rounded),
                                label: const Text('Play Now'),
                              ),
                              OutlinedButton.icon(
                                onPressed:
                                    detail.songs.isEmpty ||
                                        roomSession.controlsLocked
                                    ? null
                                    : () async {
                                        await ref
                                            .read(playbackControllerProvider)
                                            .setQueue(
                                              detail.songs,
                                              autoplay: false,
                                            );
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text('Queue loaded'),
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
              if (detail.description != null) ...[
                const SizedBox(height: 18),
                GlassPanel(
                  padding: const EdgeInsets.all(18),
                  child: Text(detail.description!),
                ),
              ],
              const SizedBox(height: 18),
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
                    ...detail.songs.asMap().entries.map(
                      (entry) => Container(
                        margin: EdgeInsets.only(
                          bottom: entry.key == detail.songs.length - 1 ? 0 : 12,
                        ),
                        decoration: BoxDecoration(
                          color: palette.surfaceInset,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: palette.border),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 4,
                          ),
                          leading: CircleAvatar(
                            radius: 18,
                            backgroundColor: palette.accentSoft,
                            child: Text(
                              '${entry.key + 1}',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: palette.accent,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                          title: Text(entry.value.title),
                          subtitle: Text(
                            '${entry.value.artistNames} / ${formatDuration(entry.value.duration)}',
                          ),
                          trailing: const Icon(Icons.play_arrow_rounded),
                          onTap: roomSession.controlsLocked
                              ? null
                              : () async {
                                  await ref
                                      .read(playbackControllerProvider)
                                      .setQueue(
                                        detail.songs,
                                        initialIndex: entry.key,
                                      );
                                  if (context.mounted) {
                                    context.push('/player');
                                  }
                                },
                        ),
                      ),
                    ),
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

class _DetailArtwork extends StatelessWidget {
  const _DetailArtwork({required this.artworkUrl, required this.fallbackIcon});

  final String? artworkUrl;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        width: 144,
        height: 144,
        child: NetworkArtwork(
          imageUrl: artworkUrl,
          fallbackIcon: fallbackIcon,
          iconSize: 40,
        ),
      ),
    );
  }
}
