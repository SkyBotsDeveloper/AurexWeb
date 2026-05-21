import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/artwork_card.dart';
import '../../../core/widgets/network_artwork.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/state_scaffold.dart';
import '../data/music_repository.dart';
import 'open_media_summary.dart';

class ArtistDetailScreen extends ConsumerWidget {
  const ArtistDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Artist')),
      body: FutureBuilder(
        future: ref.read(musicRepositoryProvider).fetchArtist(id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return StateScaffold(
              icon: Icons.error_outline_rounded,
              title: 'Unable to load artist',
              message: snapshot.error.toString(),
            );
          }
          final artist = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: NetworkArtwork(
                    imageUrl: artist.artworkUrl,
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
              ...artist.topSongs.map(
                (track) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(track.title),
                  subtitle: Text(track.artistNames),
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
