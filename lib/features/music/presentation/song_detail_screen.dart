import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/glass_panel.dart';
import '../../../core/widgets/network_artwork.dart';
import '../../../core/widgets/state_scaffold.dart';
import '../../player/data/playback_controller.dart';
import '../../rooms/data/room_session_controller.dart';
import '../data/music_repository.dart';
import 'track_support_actions.dart';

class SongDetailScreen extends ConsumerWidget {
  const SongDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppColors.of(context);
    final roomSession = ref.watch(roomSessionControllerProvider);
    final bottomPadding = MediaQuery.sizeOf(context).width >= 1120
        ? 32.0
        : 140.0;
    return Scaffold(
      appBar: AppBar(title: const Text('Song')),
      body: FutureBuilder(
        future: ref.read(musicRepositoryProvider).fetchSong(id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return StateScaffold(
              icon: Icons.error_outline_rounded,
              title: 'Unable to load song',
              message: snapshot.error.toString(),
            );
          }

          final track = snapshot.data!;
          final metadata = [
            if (track.albumName != null && track.albumName!.isNotEmpty)
              track.albumName!,
            formatDuration(track.duration),
            if (track.year != null) track.year!,
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
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: SizedBox(
                        width: 144,
                        height: 144,
                        child: NetworkArtwork(
                          imageUrl: track.artworkUrl,
                          fallbackIcon: Icons.music_note_rounded,
                          iconSize: 40,
                        ),
                      ),
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
                              'Song',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: palette.accent,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            track.title,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            track.artistNames,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          if (metadata.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              metadata,
                              style: Theme.of(context).textTheme.bodyMedium,
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
                                onPressed: roomSession.controlsLocked
                                    ? null
                                    : () async {
                                        await ref
                                            .read(playbackControllerProvider)
                                            .playTrack(track);
                                        if (context.mounted) {
                                          context.push('/player');
                                        }
                                      },
                                icon: const Icon(Icons.play_arrow_rounded),
                                label: const Text('Play Now'),
                              ),
                              OutlinedButton.icon(
                                onPressed: roomSession.controlsLocked
                                    ? null
                                    : () async {
                                        await ref
                                            .read(playbackControllerProvider)
                                            .setQueue([track], autoplay: false);
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text('Track loaded'),
                                            ),
                                          );
                                        }
                                      },
                                icon: const Icon(Icons.queue_music_rounded),
                                label: const Text('Load Track'),
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
              GlassPanel(
                padding: const EdgeInsets.all(18),
                child: TrackSupportActions(track: track),
              ),
            ],
          );
        },
      ),
    );
  }
}
