import '../../library/data/playback_stats.dart';
import '../../music/domain/music_models.dart';

class PlaybackStatsTracker {
  PlaybackStatsTracker(this._writer);

  final PlaybackStatsWriter _writer;
  Track? _activeTrack;
  String? _activeKey;
  Duration? _duration;
  Duration? _lastPosition;
  Duration _furthestPosition = Duration.zero;
  Duration _listened = Duration.zero;
  bool _started = false;
  bool _isPlaying = false;
  bool _skipRequested = false;
  bool _completionRecorded = false;
  Future<void> _pendingWrite = Future.value();

  static const meaningfulListenTime = Duration(seconds: 30);
  static const _largestNaturalPositionStep = Duration(seconds: 10);

  void updateTrack({
    required Track? track,
    required bool isPlaying,
    required bool canRecord,
    Duration? duration,
  }) {
    if (!canRecord) {
      _discardSession();
      return;
    }
    if (track == null) {
      _isPlaying = false;
      return;
    }

    final key = playbackStatsKey(track);
    if (_activeKey != null && _activeKey != key) {
      _finalizeSession();
    }
    if (_activeKey == null) {
      _activeTrack = track;
      _activeKey = key;
      _duration = duration ?? track.duration;
    } else if (duration != null) {
      _duration = duration;
    }

    _isPlaying = isPlaying;
    if (isPlaying && !_started) {
      _started = true;
      _enqueue(() => _writer.recordPlaybackStart(track));
    }
  }

  void updatePosition(Duration position, {Duration? duration}) {
    if (_activeTrack == null || !_started) {
      return;
    }
    if (duration != null) {
      _duration = duration;
    }
    if (_isPlaying && position > _furthestPosition) {
      _furthestPosition = position;
    }
    if (_isPlaying && !_completionRecorded && _isNearEnd(position, _duration)) {
      _completionRecorded = true;
      final track = _activeTrack!;
      _enqueue(
        () => _writer.recordPlaybackOutcome(
          track,
          listened: Duration.zero,
          completed: true,
          skipped: false,
        ),
      );
    }
    final previous = _lastPosition;
    _lastPosition = position;
    if (!_isPlaying || previous == null) {
      return;
    }
    final delta = position - previous;
    if (delta > Duration.zero && delta <= _largestNaturalPositionStep) {
      _listened += delta;
    }
  }

  void markUserSkip() {
    if (_activeTrack != null && _started) {
      _skipRequested = true;
    }
  }

  void finishForReplay() {
    markUserSkip();
    _finalizeSession();
  }

  Future<void> flush() async {
    _finalizeSession();
    await _pendingWrite;
  }

  void _finalizeSession() {
    final track = _activeTrack;
    if (track != null && _started) {
      final completionAlreadyRecorded = _completionRecorded;
      final completed =
          completionAlreadyRecorded || _isNearEnd(_furthestPosition, _duration);
      final skipped =
          _skipRequested && !completed && _listened < meaningfulListenTime;
      final listened = _listened;
      _enqueue(
        () => _writer.recordPlaybackOutcome(
          track,
          listened: listened,
          completed: completed && !completionAlreadyRecorded,
          skipped: skipped,
        ),
      );
    }
    _discardSession();
  }

  void _discardSession() {
    _activeTrack = null;
    _activeKey = null;
    _duration = null;
    _lastPosition = null;
    _furthestPosition = Duration.zero;
    _listened = Duration.zero;
    _started = false;
    _isPlaying = false;
    _skipRequested = false;
    _completionRecorded = false;
  }

  void _enqueue(Future<void> Function() operation) {
    _pendingWrite = _pendingWrite
        .catchError((_) {})
        .then((_) => operation())
        .catchError((_) {});
  }
}

bool _isNearEnd(Duration position, Duration? duration) {
  if (duration == null || duration <= Duration.zero) {
    return false;
  }
  final durationMs = duration.inMilliseconds;
  var thresholdMs = (durationMs * 0.8).round();
  if (duration > const Duration(minutes: 1)) {
    thresholdMs = thresholdMs < durationMs - 30000
        ? thresholdMs
        : durationMs - 30000;
  }
  return position.inMilliseconds >= thresholdMs;
}
