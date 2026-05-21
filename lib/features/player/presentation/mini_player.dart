import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/network_artwork.dart';
import '../../rooms/data/room_session_controller.dart';
import '../data/playback_controller.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppColors.of(context);
    final controller = ref.watch(playbackControllerProvider);
    final controlsLocked = ref
        .watch(roomSessionControllerProvider)
        .controlsLocked;

    return ValueListenableBuilder(
      valueListenable: controller.notifier,
      builder: (context, snapshot, child) {
        final track = snapshot.currentTrack;
        if (track == null) {
          return const SizedBox.shrink();
        }

        final durationMs = snapshot.duration?.inMilliseconds ?? 0;
        final progress = durationMs <= 0
            ? 0.0
            : (snapshot.position.inMilliseconds / durationMs).clamp(0.0, 1.0);

        return LayoutBuilder(
          builder: (context, constraints) {
            final viewport = MediaQuery.sizeOf(context);
            final compact = constraints.maxWidth < 420 || viewport.height < 760;
            final ultraCompact =
                embedded &&
                (constraints.maxWidth < 420 || viewport.height < 740);
            final sideControlSize = ultraCompact
                ? 36.0
                : (compact ? 40.0 : 48.0);

            return Container(
              margin: embedded
                  ? EdgeInsets.zero
                  : const EdgeInsets.fromLTRB(16, 0, 16, 12),
              decoration: BoxDecoration(
                color: embedded
                    ? Colors.transparent
                    : palette.surfaceElevated.withAlpha(245),
                borderRadius: BorderRadius.circular(24),
                border: embedded ? null : Border.all(color: palette.border),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () => context.push('/player'),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                      child: LinearProgressIndicator(
                        minHeight: 3,
                        value: progress,
                        backgroundColor: palette.surfaceInset,
                        valueColor: AlwaysStoppedAnimation(palette.accent),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        ultraCompact ? 8 : (compact ? 10 : 12),
                        ultraCompact ? 8 : (compact ? 10 : 12),
                        ultraCompact ? 8 : (compact ? 10 : 12),
                        ultraCompact ? 6 : (compact ? 8 : 10),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: SizedBox(
                              width: ultraCompact ? 42 : (compact ? 46 : 52),
                              height: ultraCompact ? 42 : (compact ? 46 : 52),
                              child: NetworkArtwork(
                                imageUrl: track.artworkUrl,
                                cleanArtworkQuery: track.title,
                                cleanArtworkType: 'song',
                                cleanArtworkSubtitle: track.artistNames,
                                fallbackIcon: Icons.music_note_rounded,
                                iconSize: 26,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  track.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        fontSize: ultraCompact ? 18 : null,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  controlsLocked
                                      ? 'Listening with host control'
                                      : track.artistNames,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        fontSize: ultraCompact ? 13 : null,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: controlsLocked
                                ? null
                                : controller.skipPrevious,
                            icon: const Icon(Icons.skip_previous_rounded),
                            iconSize: ultraCompact ? 22 : 24,
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints.tightFor(
                              width: sideControlSize,
                              height: sideControlSize,
                            ),
                          ),
                          FilledButton.tonal(
                            onPressed: controlsLocked
                                ? null
                                : controller.togglePlayPause,
                            style: FilledButton.styleFrom(
                              backgroundColor: palette.accent.withAlpha(36),
                              foregroundColor: palette.textPrimary,
                              minimumSize: Size(
                                ultraCompact ? 38 : (compact ? 42 : 46),
                                ultraCompact ? 38 : (compact ? 42 : 46),
                              ),
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  ultraCompact ? 14 : 16,
                                ),
                              ),
                            ),
                            child: Icon(
                              snapshot.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                            ),
                          ),
                          IconButton(
                            onPressed: controlsLocked
                                ? null
                                : controller.skipNext,
                            icon: const Icon(Icons.skip_next_rounded),
                            iconSize: ultraCompact ? 22 : 24,
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints.tightFor(
                              width: sideControlSize,
                              height: sideControlSize,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
