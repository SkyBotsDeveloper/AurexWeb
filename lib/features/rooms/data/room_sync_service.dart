import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../player/data/playback_controller.dart';
import '../../settings/data/settings_repository.dart';
import 'room_models.dart';
import 'room_repository.dart';
import 'room_session_controller.dart';

final roomSyncServiceProvider = Provider<void>((ref) {
  final service = _RoomSyncService(ref);
  ref.onDispose(service.dispose);
  ref.listen<RoomSessionState>(
    roomSessionControllerProvider,
    (_, next) => service.handleRoomSession(next),
    fireImmediately: true,
  );
});

class _RoomSyncService {
  _RoomSyncService(this._ref);

  final Ref _ref;
  StreamSubscription<RoomPlaybackState?>? _playbackSubscription;
  PlaybackController? _hostPlaybackController;
  Timer? _hostSyncDebounce;

  String? _activeRoomId;
  bool _isHost = false;
  int _lastAppliedSequence = -1;
  String? _lastHostSyncSignature;
  bool _listenerSyncRunning = false;
  RoomPlaybackState? _pendingPlaybackState;

  void handleRoomSession(RoomSessionState session) {
    final roomChanged = session.roomId != _activeRoomId;
    final roleChanged = session.isHost != _isHost;

    _activeRoomId = session.roomId;
    _isHost = session.isHost;

    if (!session.hasActiveRoom) {
      _resetBindings();
      return;
    }

    if (!roomChanged && !roleChanged) {
      return;
    }

    _lastAppliedSequence = -1;
    _lastHostSyncSignature = null;
    _pendingPlaybackState = null;
    _listenerSyncRunning = false;
    _detachHostSync();
    unawaited(_playbackSubscription?.cancel());
    _playbackSubscription = null;

    if (session.isHost) {
      _attachHostSync();
      return;
    }

    _playbackSubscription = _ref
        .read(roomRepositoryProvider)
        .watchPlaybackState(session.roomId!)
        .listen((playbackState) {
          if (playbackState == null) {
            return;
          }
          _queueListenerSync(playbackState);
        });
  }

  Future<void> dispose() async {
    _hostSyncDebounce?.cancel();
    _detachHostSync();
    await _playbackSubscription?.cancel();
  }

  void _resetBindings() {
    _lastAppliedSequence = -1;
    _lastHostSyncSignature = null;
    _pendingPlaybackState = null;
    _listenerSyncRunning = false;
    _detachHostSync();
    unawaited(_playbackSubscription?.cancel());
    _playbackSubscription = null;
  }

  void _attachHostSync() {
    final controller = _ref.read(playbackControllerProvider);
    _hostPlaybackController = controller;
    controller.notifier.addListener(_scheduleHostSync);
    _scheduleHostSync();
  }

  void _detachHostSync() {
    _hostPlaybackController?.notifier.removeListener(_scheduleHostSync);
    _hostPlaybackController = null;
    _hostSyncDebounce?.cancel();
  }

  void _scheduleHostSync() {
    _hostSyncDebounce?.cancel();
    _hostSyncDebounce = Timer(
      const Duration(milliseconds: 450),
      _syncHostPlayback,
    );
  }

  Future<void> _syncHostPlayback() async {
    final roomId = _activeRoomId;
    if (!_isHost || roomId == null || roomId.isEmpty) {
      return;
    }

    final snapshot = _ref.read(playbackControllerProvider).snapshot;
    if (snapshot.queue.isEmpty) {
      return;
    }

    final signature = [
      snapshot.currentTrack?.id ?? '',
      snapshot.currentIndex ?? -1,
      snapshot.position.inMilliseconds ~/ 1000,
      snapshot.isPlaying ? 1 : 0,
      snapshot.queue.length,
    ].join(':');

    if (signature == _lastHostSyncSignature) {
      return;
    }
    _lastHostSyncSignature = signature;

    try {
      await _ref.read(roomRepositoryProvider).syncPlayback(roomId, snapshot);
    } catch (_) {
      // Room sync failures should not interrupt local playback.
    }
  }

  Future<void> _applyListenerSync(RoomPlaybackState playbackState) async {
    final roomId = _activeRoomId;
    if (_isHost || roomId == null || playbackState.roomId != roomId) {
      return;
    }

    final settings = _ref.read(settingsRepositoryProvider).current;
    if (!settings.autoResyncRooms ||
        playbackState.sequence <= _lastAppliedSequence) {
      return;
    }

    final controller = _ref.read(playbackControllerProvider);
    final local = controller.snapshot;
    final trackChanged =
        local.currentTrack?.id != playbackState.currentTrack?.id;
    final driftMs = (local.position.inMilliseconds - playbackState.positionMs)
        .abs();

    _lastAppliedSequence = playbackState.sequence;

    if (trackChanged || driftMs > 2500) {
      await controller.setQueue(
        playbackState.queue,
        initialIndex: playbackState.queueIndex,
        initialPosition: Duration(milliseconds: playbackState.positionMs),
        autoplay: playbackState.isPlaying,
        bypassRoomLock: true,
      );
      return;
    }

    if (driftMs > 750) {
      await controller.seek(
        Duration(milliseconds: playbackState.positionMs),
        bypassRoomLock: true,
      );
    }

    if (playbackState.isPlaying != local.isPlaying) {
      await controller.togglePlayPause(bypassRoomLock: true);
    }
  }

  void _queueListenerSync(RoomPlaybackState playbackState) {
    if (_pendingPlaybackState == null ||
        playbackState.sequence >= _pendingPlaybackState!.sequence) {
      _pendingPlaybackState = playbackState;
    }
    if (_listenerSyncRunning) {
      return;
    }
    _listenerSyncRunning = true;
    unawaited(_drainListenerSyncQueue());
  }

  Future<void> _drainListenerSyncQueue() async {
    try {
      while (true) {
        final next = _pendingPlaybackState;
        if (next == null) {
          return;
        }
        _pendingPlaybackState = null;
        await _applyListenerSync(next);
      }
    } finally {
      _listenerSyncRunning = false;
      if (_pendingPlaybackState != null) {
        _queueListenerSync(_pendingPlaybackState!);
      }
    }
  }
}
