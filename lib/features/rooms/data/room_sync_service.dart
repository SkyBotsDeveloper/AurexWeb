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

  String? _activeRoomId;
  bool _isHost = false;
  int _lastAppliedSequence = -1;
  String? _lastHostStructuralSignature;
  int? _lastHostPositionBucket;
  bool _hostSyncRunning = false;
  bool _hostSyncPending = false;
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
    _lastHostStructuralSignature = null;
    _lastHostPositionBucket = null;
    _hostSyncRunning = false;
    _hostSyncPending = false;
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
    _detachHostSync();
    await _playbackSubscription?.cancel();
  }

  void _resetBindings() {
    _lastAppliedSequence = -1;
    _lastHostStructuralSignature = null;
    _lastHostPositionBucket = null;
    _hostSyncRunning = false;
    _hostSyncPending = false;
    _pendingPlaybackState = null;
    _listenerSyncRunning = false;
    _detachHostSync();
    unawaited(_playbackSubscription?.cancel());
    _playbackSubscription = null;
  }

  void _attachHostSync() {
    final controller = _ref.read(playbackControllerProvider);
    _hostPlaybackController = controller;
    controller.notifier.addListener(_requestHostSync);
    _requestHostSync();
  }

  void _detachHostSync() {
    _hostPlaybackController?.notifier.removeListener(_requestHostSync);
    _hostPlaybackController = null;
  }

  void _requestHostSync() {
    _hostSyncPending = true;
    if (_hostSyncRunning) {
      return;
    }
    _hostSyncRunning = true;
    unawaited(_drainHostSyncQueue());
  }

  Future<void> _drainHostSyncQueue() async {
    try {
      while (_hostSyncPending) {
        _hostSyncPending = false;
        await _syncHostPlayback();
      }
    } finally {
      _hostSyncRunning = false;
      if (_hostSyncPending) {
        _requestHostSync();
      }
    }
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

    final structuralSignature = [
      snapshot.currentTrack?.id ?? '',
      snapshot.currentIndex ?? -1,
      snapshot.isPlaying ? 1 : 0,
      snapshot.queue.length,
    ].join(':');
    final positionBucket =
        snapshot.position.inMilliseconds ~/ (snapshot.isPlaying ? 1500 : 750);

    final structuralChanged =
        structuralSignature != _lastHostStructuralSignature;
    final positionChanged = positionBucket != _lastHostPositionBucket;

    if (!structuralChanged && !positionChanged) {
      return;
    }

    try {
      await _ref.read(roomRepositoryProvider).syncPlayback(roomId, snapshot);
      _lastHostStructuralSignature = structuralSignature;
      _lastHostPositionBucket = positionBucket;
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
