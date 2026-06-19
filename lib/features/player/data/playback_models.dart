import 'package:just_audio/just_audio.dart';

import '../../music/domain/music_models.dart';

class PlaybackSnapshot {
  const PlaybackSnapshot({
    this.queue = const [],
    this.currentIndex,
    this.position = Duration.zero,
    this.bufferedPosition = Duration.zero,
    this.duration,
    this.isPlaying = false,
    this.isBuffering = false,
    this.isResuming = false,
    this.loopMode = LoopMode.off,
    this.shuffleEnabled = false,
    this.error,
  });

  final List<Track> queue;
  final int? currentIndex;
  final Duration position;
  final Duration bufferedPosition;
  final Duration? duration;
  final bool isPlaying;
  final bool isBuffering;
  final bool isResuming;
  final LoopMode loopMode;
  final bool shuffleEnabled;
  final String? error;

  Track? get currentTrack {
    if (currentIndex == null || currentIndex! < 0 || currentIndex! >= queue.length) {
      return null;
    }
    return queue[currentIndex!];
  }

  PlaybackSnapshot copyWith({
    List<Track>? queue,
    int? currentIndex,
    Duration? position,
    Duration? bufferedPosition,
    Duration? duration,
    bool? isPlaying,
    bool? isBuffering,
    bool? isResuming,
    LoopMode? loopMode,
    bool? shuffleEnabled,
    String? error,
    bool clearError = false,
  }) {
    return PlaybackSnapshot(
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      position: position ?? this.position,
      bufferedPosition: bufferedPosition ?? this.bufferedPosition,
      duration: duration ?? this.duration,
      isPlaying: isPlaying ?? this.isPlaying,
      isBuffering: isBuffering ?? this.isBuffering,
      isResuming: isResuming ?? this.isResuming,
      loopMode: loopMode ?? this.loopMode,
      shuffleEnabled: shuffleEnabled ?? this.shuffleEnabled,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class DownloadTaskProgress {
  const DownloadTaskProgress({
    required this.trackId,
    required this.progress,
    required this.isRunning,
    this.error,
  });

  final String trackId;
  final double progress;
  final bool isRunning;
  final String? error;
}
