import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/error_messages.dart';
import '../../../core/widgets/artwork_card.dart';
import '../../../core/widgets/network_artwork.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../../core/widgets/state_scaffold.dart';
import '../../player/data/playback_controller.dart';
import '../../rooms/data/room_session_controller.dart';
import '../data/music_repository.dart';
import '../domain/music_models.dart';
import 'open_media_summary.dart';

final artistDetailProvider = FutureProvider.autoDispose
    .family<ArtistDetail, String>(
      (ref, id) => ref.read(musicRepositoryProvider).fetchArtist(id),
    );

class ArtistDetailScreen extends ConsumerWidget {
  const ArtistDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomSession = ref.watch(roomSessionControllerProvider);
    final artistState = ref.watch(artistDetailProvider(id));

    return Scaffold(
      appBar: AppBar(title: const Text('Artist')),
      body: artistState.when(
        loading: () => const MediaDetailSkeleton(rowCount: 5),
        error: (error, _) => StateScaffold(
          icon: Icons.error_outline_rounded,
          title: 'Unable to load artist',
          message: friendlyErrorMessage(error),
        ),
        data: (artist) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: NetworkArtwork(
                    imageUrl: artist.artworkUrl,
                    cleanArtworkQuery: artist.name,
                    cleanArtworkType: 'artist',
                    fallbackIcon: Icons.person_rounded,
                    iconSize: 64,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                artist.name,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(artist.bio ?? 'No biography available.'),
              const SizedBox(height: 20),
              SectionHeader(title: 'Top Albums'),
              const SizedBox(height: 12),
              SizedBox(
                height: 232,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: artist.topAlbums.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 14),
                  itemBuilder: (context, index) => ArtworkCard(
                    item: artist.topAlbums[index],
                    onTap: () =>
                        openMediaSummary(context, ref, artist.topAlbums[index]),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SectionHeader(title: 'Top Songs'),
              const SizedBox(height: 12),
              ...artist.topSongs.asMap().entries.map(
                (entry) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(entry.value.title),
                  subtitle: Text(
                    roomSession.controlsLocked
                        ? roomPlaybackLockedMessage(roomSession)
                        : entry.value.artistNames,
                  ),
                  trailing: Icon(
                    roomSession.controlsLocked
                        ? Icons.lock_outline_rounded
                        : Icons.play_arrow_rounded,
                  ),
                  onTap: roomSession.controlsLocked
                      ? null
                      : () async {
                          await ref
                              .read(playbackControllerProvider)
                              .setQueue(
                                artist.topSongs,
                                initialIndex: entry.key,
                              );
                          if (context.mounted) {
                            context.push('/player');
                          }
                        },
                ),
              ),
              if (artist.similarArtists.isNotEmpty) ...[
                const SizedBox(height: 24),
                SectionHeader(title: 'Related Artists'),
                const SizedBox(height: 12),
                SizedBox(
                  height: 232,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: artist.similarArtists.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 14),
                    itemBuilder: (context, index) => ArtworkCard(
                      item: artist.similarArtists[index],
                      onTap: () => openMediaSummary(
                        context,
                        ref,
                        artist.similarArtists[index],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
