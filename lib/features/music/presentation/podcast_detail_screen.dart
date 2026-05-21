import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/glass_panel.dart';
import '../../../core/widgets/network_artwork.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../../core/widgets/state_scaffold.dart';
import '../../player/data/playback_controller.dart';
import '../../rooms/data/room_session_controller.dart';
import '../data/music_repository.dart';
import '../domain/music_models.dart';

class PodcastDetailScreen extends ConsumerWidget {
  const PodcastDetailScreen({super.key, required this.id, this.initial});

  final String id;
  final MediaSummary? initial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final future = ref.read(musicRepositoryProvider).fetchPodcast(id);
    final bottomPadding = MediaQuery.sizeOf(context).width >= 1120
        ? 32.0
        : 140.0;

    return Scaffold(
      appBar: AppBar(title: const Text('Show')),
      body: FutureBuilder<PodcastDetail>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const MediaDetailSkeleton(rowCount: 6);
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return StateScaffold(
              icon: Icons.error_outline_rounded,
              title: 'Unable to open this show',
              message: friendlyErrorMessage(snapshot.error),
            );
          }

          final detail = _mergeInitial(snapshot.data!);
          return ListView(
            padding: EdgeInsets.fromLTRB(20, 20, 20, bottomPadding),
            children: [
              _PodcastHero(detail: detail),
              const SizedBox(height: 18),
              GlassPanel(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Episodes',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 14),
                    if (detail.episodes.isEmpty)
                      const StateScaffold(
                        icon: Icons.podcasts_rounded,
                        title: 'No episodes available',
                        message:
                            'This source did not return playable episodes right now.',
                      )
                    else
                      ...detail.episodes.asMap().entries.map(
                        (entry) => _EpisodeTile(
                          episode: entry.value,
                          queue: detail.episodes,
                          index: entry.key,
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

  PodcastDetail _mergeInitial(PodcastDetail fetched) {
    final fallback = initial;
    if (fallback == null) {
      return fetched;
    }
    return PodcastDetail(
      id: fetched.id.isNotEmpty ? fetched.id : fallback.id,
      title: fetched.title.trim().isNotEmpty ? fetched.title : fallback.title,
      description: fetched.description ?? fallback.description,
      image: fetched.image.isNotEmpty ? fetched.image : fallback.image,
      language: fetched.language ?? fallback.language,
      fanCount: fetched.fanCount ?? fallback.followerCount,
      totalEpisodes: fetched.totalEpisodes ?? fallback.songCount,
      episodes: fetched.episodes,
    );
  }
}

class _PodcastHero extends ConsumerWidget {
  const _PodcastHero({required this.detail});

  final PodcastDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppColors.of(context);
    final roomSession = ref.watch(roomSessionControllerProvider);
    final metadata = [
      if (detail.totalEpisodes != null) '${detail.totalEpisodes} episodes',
      if (detail.language != null) detail.language!,
      if (detail.fanCount != null) '${detail.fanCount} fans',
    ].join(' / ');

    return GlassPanel(
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
                imageUrl: detail.artworkUrl,
                fallbackIcon: Icons.podcasts_rounded,
                iconSize: 42,
              ),
            ),
          ),
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
                    'Show',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
                  Text(metadata, style: Theme.of(context).textTheme.bodyLarge),
                ],
                if ((detail.description ?? '').isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    detail.description!,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
                if (roomSession.controlsLocked) ...[
                  const SizedBox(height: 10),
                  Text(
                    roomPlaybackLockedMessage(roomSession),
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: palette.warning),
                  ),
                ],
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed:
                          detail.episodes.isEmpty || roomSession.controlsLocked
                          ? null
                          : () => _setPodcastQueue(
                              context,
                              ref,
                              detail.episodes,
                              autoplay: true,
                            ),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Play Latest'),
                    ),
                    OutlinedButton.icon(
                      onPressed:
                          detail.episodes.isEmpty || roomSession.controlsLocked
                          ? null
                          : () => _setPodcastQueue(
                              context,
                              ref,
                              detail.episodes,
                              autoplay: false,
                            ),
                      icon: const Icon(Icons.queue_music_rounded),
                      label: const Text('Load Episodes'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EpisodeTile extends ConsumerWidget {
  const _EpisodeTile({
    required this.episode,
    required this.queue,
    required this.index,
  });

  final Track episode;
  final List<Track> queue;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppColors.of(context);
    final roomSession = ref.watch(roomSessionControllerProvider);

    return Container(
      margin: EdgeInsets.only(bottom: index == queue.length - 1 ? 0 : 12),
      decoration: BoxDecoration(
        color: palette.surfaceInset,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 48,
            height: 48,
            child: NetworkArtwork(
              imageUrl: episode.artworkUrl,
              fallbackIcon: Icons.podcasts_rounded,
              iconSize: 26,
            ),
          ),
        ),
        title: Text(episode.title),
        subtitle: Text(
          [
            episode.albumName,
            formatDuration(episode.duration),
          ].whereType<String>().where((item) => item.isNotEmpty).join(' / '),
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
                    .setQueue(queue, initialIndex: index);
                if (context.mounted) {
                  context.push('/player');
                }
              },
      ),
    );
  }
}

Future<void> _setPodcastQueue(
  BuildContext context,
  WidgetRef ref,
  List<Track> episodes, {
  required bool autoplay,
}) async {
  try {
    await ref
        .read(playbackControllerProvider)
        .setQueue(episodes, autoplay: autoplay);
    if (!context.mounted) {
      return;
    }
    if (autoplay) {
      context.push('/player');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${episodes.length} episodes loaded')),
      );
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(error))));
    }
  }
}
