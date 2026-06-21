import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/glass_panel.dart';
import '../../../core/widgets/network_artwork.dart';
import '../../../core/widgets/state_scaffold.dart';
import '../../music/data/music_repository.dart';
import '../../music/domain/music_models.dart';
import '../../music/presentation/track_support_actions.dart';
import '../../rooms/data/room_session_controller.dart';
import '../data/playback_controller.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  bool _showLyrics = false;
  _LyricsAvailability _lyricsAvailability = _LyricsAvailability.loading;
  LyricsBundle? _lyricsBundle;
  String? _lyricsTrackKey;
  int _lyricsRequestId = 0;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final controller = ref.watch(playbackControllerProvider);
    final roomSession = ref.watch(roomSessionControllerProvider);
    final controlsLocked = roomSession.controlsLocked;

    return Scaffold(
      appBar: AppBar(title: const Text('Now Playing')),
      body: ValueListenableBuilder(
        valueListenable: controller.notifier,
        builder: (context, snapshot, child) {
          final track = snapshot.currentTrack;
          if (track == null) {
            _syncLyricsTrack(null);
            return const StateScaffold(
              icon: Icons.music_off_rounded,
              title: 'Nothing is playing',
              message: 'Choose a track from Home, Search, or Library.',
            );
          }

          _syncLyricsTrack(track);

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final artworkSize = constraints.maxWidth >= 720
                      ? 188.0
                      : 144.0;
                  return GlassPanel(
                    padding: const EdgeInsets.all(18),
                    child: Wrap(
                      spacing: 18,
                      runSpacing: 18,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: SizedBox(
                            width: artworkSize,
                            height: artworkSize,
                            child: NetworkArtwork(
                              imageUrl: track.artworkUrl,
                              cleanArtworkQuery: track.title,
                              cleanArtworkType: 'song',
                              cleanArtworkSubtitle: track.artistNames,
                              fallbackIcon: Icons.music_note_rounded,
                              iconSize: 56,
                            ),
                          ),
                        ),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 460),
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
                                  'Now Playing',
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
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                track.artistNames,
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                              if ((track.albumName ?? '').isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  track.albumName!,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 18),
              if (controlsLocked) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.lock_outline_rounded),
                  title: const Text('Host-only playback'),
                  subtitle: Text(roomPlaybackLockedMessage(roomSession)),
                ),
                const SizedBox(height: 12),
              ],
              Slider(
                value: snapshot.position.inMilliseconds
                    .clamp(
                      0,
                      (snapshot.duration ?? Duration.zero).inMilliseconds,
                    )
                    .toDouble(),
                max:
                    ((snapshot.duration ?? const Duration(seconds: 1))
                            .inMilliseconds)
                        .toDouble()
                        .clamp(1, double.infinity),
                onChanged: controlsLocked
                    ? null
                    : (value) => controller.seek(
                        Duration(milliseconds: value.round()),
                      ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(formatDuration(snapshot.position)),
                  Text(formatDuration(snapshot.duration)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  IconButton(
                    onPressed: controlsLocked ? null : controller.toggleShuffle,
                    icon: Icon(
                      Icons.shuffle_rounded,
                      color: snapshot.shuffleEnabled
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                  ),
                  IconButton(
                    onPressed: controlsLocked ? null : controller.skipPrevious,
                    iconSize: 36,
                    icon: const Icon(Icons.skip_previous_rounded),
                  ),
                  FilledButton(
                    onPressed: controlsLocked || snapshot.isResuming
                        ? null
                        : controller.togglePlayPause,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(76, 76),
                      shape: const CircleBorder(),
                    ),
                    child: snapshot.isResuming
                        ? const SizedBox.square(
                            dimension: 30,
                            child: CircularProgressIndicator(strokeWidth: 3),
                          )
                        : Icon(
                            snapshot.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            size: 38,
                          ),
                  ),
                  IconButton(
                    onPressed: controlsLocked ? null : controller.skipNext,
                    iconSize: 36,
                    icon: const Icon(Icons.skip_next_rounded),
                  ),
                  IconButton(
                    onPressed: controlsLocked
                        ? null
                        : controller.cycleRepeatMode,
                    icon: Icon(
                      snapshot.loopMode == LoopMode.one
                          ? Icons.repeat_one_rounded
                          : Icons.repeat_rounded,
                      color: snapshot.loopMode == LoopMode.off
                          ? null
                          : Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TrackSupportActions(track: track),
              const SizedBox(height: 24),
              if (_lyricsAvailability == _LyricsAvailability.available) ...[
                FilledButton.tonalIcon(
                  onPressed: _toggleLyrics,
                  icon: Icon(
                    _showLyrics ? Icons.lyrics_rounded : Icons.lyrics_outlined,
                  ),
                  label: Text(_showLyrics ? 'Hide Lyrics' : 'Lyrics'),
                ),
                if (_showLyrics && _lyricsBundle != null) ...[
                  const SizedBox(height: 24),
                  _LyricsSection(bundle: _lyricsBundle!),
                ],
                const SizedBox(height: 24),
              ],
              Text('Queue', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              ...snapshot.queue.asMap().entries.map(
                (entry) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Text(
                    '${entry.key + 1}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  title: Text(entry.value.title),
                  subtitle: Text(entry.value.artistNames),
                  selected: entry.key == snapshot.currentIndex,
                  trailing: entry.key == snapshot.currentIndex
                      ? const Icon(Icons.graphic_eq_rounded)
                      : null,
                  onTap: controlsLocked
                      ? null
                      : () => controller.playAtIndex(entry.key),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _syncLyricsTrack(Track? track) {
    final trackKey = track == null
        ? null
        : '${track.source}:${track.id}:${track.lyricsId ?? ''}';
    if (_lyricsTrackKey == trackKey) {
      return;
    }

    _lyricsTrackKey = trackKey;
    _showLyrics = false;
    _lyricsBundle = null;
    _lyricsAvailability = _LyricsAvailability.loading;
    final requestId = ++_lyricsRequestId;
    if (track == null) {
      return;
    }

    final lookup = ref.read(musicRepositoryProvider).fetchBestLyrics(track);
    unawaited(_completeLyricsLookup(lookup, trackKey!, requestId));
  }

  Future<void> _completeLyricsLookup(
    Future<LyricsBundle> lookup,
    String trackKey,
    int requestId,
  ) async {
    try {
      final bundle = await lookup;
      if (!mounted ||
          requestId != _lyricsRequestId ||
          trackKey != _lyricsTrackKey) {
        return;
      }
      setState(() {
        _lyricsBundle = bundle.hasAny ? bundle : null;
        _lyricsAvailability = bundle.hasAny
            ? _LyricsAvailability.available
            : _LyricsAvailability.unavailable;
      });
    } catch (_) {
      if (!mounted ||
          requestId != _lyricsRequestId ||
          trackKey != _lyricsTrackKey) {
        return;
      }
      setState(() {
        _showLyrics = false;
        _lyricsBundle = null;
        _lyricsAvailability = _LyricsAvailability.error;
      });
    }
  }

  void _toggleLyrics() {
    if (_lyricsAvailability != _LyricsAvailability.available ||
        _lyricsBundle == null) {
      setState(() => _showLyrics = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lyrics could not be loaded right now.')),
      );
      return;
    }
    setState(() => _showLyrics = !_showLyrics);
  }
}

enum _LyricsAvailability { loading, available, unavailable, error }

class _LyricsSection extends StatelessWidget {
  const _LyricsSection({required this.bundle});

  final LyricsBundle bundle;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                bundle.hasSynced ? 'Synced Lyrics' : 'Lyrics',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (bundle.usedFallback)
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
                  bundle.sourceLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: palette.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (bundle.hasSynced)
          _SyncedLyricsView(lines: bundle.synced!.lines)
        else
          Text(
            bundle.plain!.lyrics,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.8),
          ),
      ],
    );
  }
}

class _SyncedLyricsView extends ConsumerStatefulWidget {
  const _SyncedLyricsView({required this.lines});

  final List<SyncedLyricLine> lines;

  @override
  ConsumerState<_SyncedLyricsView> createState() => _SyncedLyricsViewState();
}

class _SyncedLyricsViewState extends ConsumerState<_SyncedLyricsView> {
  final ItemScrollController _scrollController = ItemScrollController();
  int _lastActiveIndex = -1;

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(playbackControllerProvider);
    return ValueListenableBuilder(
      valueListenable: controller.notifier,
      builder: (context, snapshot, child) {
        final currentMs = snapshot.position.inMilliseconds;
        final activeIndex = widget.lines.indexWhere(
          (line) =>
              currentMs >= line.startTimeMs && currentMs <= line.endTimeMs,
        );

        if (activeIndex >= 0 &&
            activeIndex != _lastActiveIndex &&
            _scrollController.isAttached) {
          _lastActiveIndex = activeIndex;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollController.scrollTo(
              index: activeIndex,
              duration: const Duration(milliseconds: 240),
              alignment: 0.3,
            );
          });
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 320,
              child: ScrollablePositionedList.builder(
                itemScrollController: _scrollController,
                itemCount: widget.lines.length,
                itemBuilder: (context, index) {
                  final line = widget.lines[index];
                  final isActive = index == activeIndex;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      line.text,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontSize: isActive ? 20 : 16,
                        fontWeight: isActive
                            ? FontWeight.w700
                            : FontWeight.w400,
                        color: isActive
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
