import 'dart:async';
import 'dart:convert';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_providers.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/storage/file_ops.dart';
import '../../../core/utils/error_messages.dart';
import '../../music/data/aurex_api_client.dart';
import '../../library/data/library_repository.dart';
import '../../music/domain/music_models.dart';
import '../../rooms/data/room_session_controller.dart';
import '../../settings/data/settings_repository.dart';
import 'playback_models.dart';

final playbackControllerProvider = Provider<PlaybackController>((ref) {
  final controller = PlaybackController(
    ref,
    ref.watch(sharedPreferencesProvider),
    ref.watch(libraryRepositoryProvider),
    ref.watch(settingsRepositoryProvider),
  );
  ref.onDispose(() {
    unawaited(controller.dispose());
  });
  return controller;
});

class PlaybackController {
  PlaybackController(
    this._ref,
    this._prefs,
    this._libraryRepository,
    this._settingsRepository,
  ) : _player = AudioPlayer() {
    _bindPlayer();
    unawaited(_restoreSession());
  }

  final Ref _ref;
  final SharedPreferences _prefs;
  final LibraryRepository _libraryRepository;
  final SettingsRepository _settingsRepository;
  final AudioPlayer _player;
  final ValueNotifier<PlaybackSnapshot> notifier = ValueNotifier(
    const PlaybackSnapshot(),
  );
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Future<void> _queueOperation = Future.value();
  int _queueRequestVersion = 0;

  static const _queueKey = 'playback.queue';
  static const _indexKey = 'playback.index';
  static const _positionKey = 'playback.position_ms';
  static const _playingKey = 'playback.playing';

  PlaybackSnapshot get snapshot => notifier.value;

  Future<void> playTrack(Track track, {bool bypassRoomLock = false}) async {
    if (!_canControl(bypassRoomLock)) {
      return;
    }
    await setQueue([track], bypassRoomLock: bypassRoomLock);
  }

  Future<void> setQueue(
    List<Track> queue, {
    int initialIndex = 0,
    Duration initialPosition = Duration.zero,
    bool autoplay = true,
    bool bypassRoomLock = false,
  }) async {
    if (!_canControl(bypassRoomLock)) {
      return;
    }
    if (queue.isEmpty) {
      return;
    }

    final requestVersion = ++_queueRequestVersion;
    _queueOperation = _queueOperation
        .catchError((_) {})
        .then(
          (_) => _performSetQueue(
            queue,
            initialIndex: initialIndex,
            initialPosition: initialPosition,
            autoplay: autoplay,
            requestVersion: requestVersion,
          ),
        );
    await _queueOperation;
  }

  Future<void> _performSetQueue(
    List<Track> queue, {
    required int initialIndex,
    required Duration initialPosition,
    required bool autoplay,
    required int requestVersion,
  }) async {
    if (requestVersion != _queueRequestVersion) {
      return;
    }

    await _ensureNotificationPermission();

    final sources = <AudioSource>[];
    final playableTracks = <Track>[];

    for (final track in queue) {
      final uri = await _resolveTrackUri(track);
      if (uri == null) {
        AppLogger.instance.w(
          'Skipping unplayable track because no audio source was resolved',
          error: track.title,
        );
        continue;
      }
      playableTracks.add(track);
      sources.add(
        AudioSource.uri(
          uri,
          tag: MediaItem(
            id: track.id,
            title: track.title,
            album: track.albumName,
            artist: track.artistNames,
            artUri: track.artworkUrl == null
                ? null
                : Uri.tryParse(track.artworkUrl!),
            duration: track.duration,
          ),
        ),
      );
    }

    if (requestVersion != _queueRequestVersion) {
      return;
    }

    if (sources.isEmpty) {
      throw StateError(
        'This track is not playable right now. Try another song or retry in a moment.',
      );
    }

    final safeIndex = initialIndex.clamp(0, playableTracks.length - 1);
    AppLogger.instance.i(
      'Replacing playback queue with ${playableTracks.length} track(s); '
      'index=$safeIndex; autoplay=$autoplay; uri=${sources[safeIndex].sequence.first.tag is MediaItem ? (sources[safeIndex].sequence.first.tag as MediaItem).id : playableTracks[safeIndex].id}',
    );
    await _resetPlaybackForReplacement();
    await _player.setAudioSources(
      sources,
      initialIndex: safeIndex,
      initialPosition: initialPosition,
      preload: false,
    );

    if (requestVersion != _queueRequestVersion) {
      return;
    }

    final loadedDuration = await _player.load();

    if (requestVersion != _queueRequestVersion) {
      return;
    }

    notifier.value = notifier.value.copyWith(
      queue: playableTracks,
      currentIndex: safeIndex,
      position: initialPosition,
      bufferedPosition: Duration.zero,
      duration: loadedDuration ?? playableTracks[safeIndex].duration,
      isPlaying: false,
      isBuffering: autoplay,
      clearError: true,
    );

    await _persistSession();
    if (autoplay) {
      await _playPreparedQueue(
        initialPosition: initialPosition,
        requestVersion: requestVersion,
      );
    }
  }

  Future<void> _resetPlaybackForReplacement() async {
    if (_player.playing) {
      AppLogger.instance.d('Pausing active playback before queue replacement');
      await _player.pause();
    }
    AppLogger.instance.d('Stopping player before queue replacement');
    await _player.stop();
  }

  Future<void> _playPreparedQueue({
    required Duration initialPosition,
    required int requestVersion,
  }) async {
    AppLogger.instance.d(
      'Ensuring playback starts for prepared queue; '
      'index=${_player.currentIndex}; '
      'positionMs=${initialPosition.inMilliseconds}; '
      'requestVersion=$requestVersion',
    );
    final started = await _ensurePlaybackStarted(
      requestVersion: requestVersion,
      initialPosition: initialPosition,
    );
    if (!started && requestVersion == _queueRequestVersion) {
      notifier.value = notifier.value.copyWith(
        error: 'Playback could not be started right now. Please retry.',
      );
      AppLogger.instance.w(
        'Playback did not start after retries for requestVersion=$requestVersion',
      );
    }
  }

  Future<bool> _ensurePlaybackStarted({
    required int requestVersion,
    required Duration initialPosition,
  }) async {
    final targetIndex = _player.currentIndex;
    for (var attempt = 0; attempt < 5; attempt++) {
      if (requestVersion != _queueRequestVersion) {
        return false;
      }
      if (_player.playing) {
        return true;
      }
      if (attempt > 0) {
        await _player.seek(initialPosition, index: targetIndex);
      }
      AppLogger.instance.d(
        'Playback start attempt ${attempt + 1} for index=$targetIndex '
        'requestVersion=$requestVersion',
      );
      _launchPlayRequest();
      final started = await _waitForPlaybackStart(
        requestVersion: requestVersion,
      );
      if (started) {
        return true;
      }
      await Future<void>.delayed(const Duration(milliseconds: 180));
    }
    return _player.playing;
  }

  Future<bool> _waitForPlaybackStart({required int requestVersion}) async {
    if (_player.playing) {
      return true;
    }
    try {
      final state = await _player.playerStateStream
          .firstWhere((state) => state.playing)
          .timeout(const Duration(milliseconds: 700));
      return requestVersion == _queueRequestVersion && state.playing;
    } on TimeoutException {
      return _player.playing;
    }
  }

  void _launchPlayRequest() {
    AppLogger.instance.d(
      'Dispatching non-blocking play() request; '
      'index=${_player.currentIndex}; playing=${_player.playing}; '
      'processing=${_player.processingState.name}',
    );
    final playFuture = _player.play();
    unawaited(
      playFuture.catchError((Object error, StackTrace stackTrace) {
        notifier.value = notifier.value.copyWith(
          error: friendlyErrorMessage(
            error,
            fallback: 'Playback could not be started right now.',
          ),
        );
        AppLogger.instance.e(
          'Playback play request failed',
          error: error,
          stackTrace: stackTrace,
        );
      }),
    );
  }

  Future<void> togglePlayPause({bool bypassRoomLock = false}) async {
    if (!_canControl(bypassRoomLock)) {
      return;
    }
    if (_player.playing) {
      await _player.pause();
    } else {
      _launchPlayRequest();
    }
    await _persistSession();
  }

  Future<void> playAtIndex(int index, {bool bypassRoomLock = false}) async {
    if (!_canControl(bypassRoomLock)) {
      return;
    }
    if (snapshot.queue.isEmpty) {
      return;
    }

    final safeIndex = index.clamp(0, snapshot.queue.length - 1);
    await _player.seek(Duration.zero, index: safeIndex);
    notifier.value = notifier.value.copyWith(
      currentIndex: safeIndex,
      position: Duration.zero,
      duration: snapshot.queue[safeIndex].duration,
      clearError: true,
    );
    _launchPlayRequest();
    await _persistSession();
  }

  Future<void> seek(Duration position, {bool bypassRoomLock = false}) async {
    if (!_canControl(bypassRoomLock)) {
      return;
    }
    await _player.seek(position);
    notifier.value = notifier.value.copyWith(position: position);
    await _persistSession();
  }

  Future<void> skipNext({bool bypassRoomLock = false}) async {
    if (!_canControl(bypassRoomLock)) {
      return;
    }
    if (_player.hasNext) {
      await _player.seekToNext();
      await _persistSession();
    }
  }

  Future<void> skipPrevious({bool bypassRoomLock = false}) async {
    if (!_canControl(bypassRoomLock)) {
      return;
    }
    if (_player.position > const Duration(seconds: 3)) {
      await _player.seek(Duration.zero);
      await _persistSession();
      return;
    }
    if (_player.hasPrevious) {
      await _player.seekToPrevious();
      await _persistSession();
    }
  }

  Future<void> toggleShuffle({bool bypassRoomLock = false}) async {
    if (!_canControl(bypassRoomLock)) {
      return;
    }
    final next = !_player.shuffleModeEnabled;
    if (next) {
      await _player.shuffle();
    }
    await _player.setShuffleModeEnabled(next);
  }

  Future<void> cycleRepeatMode({bool bypassRoomLock = false}) async {
    if (!_canControl(bypassRoomLock)) {
      return;
    }
    final next = switch (_player.loopMode) {
      LoopMode.off => LoopMode.all,
      LoopMode.all => LoopMode.one,
      LoopMode.one => LoopMode.off,
    };
    await _player.setLoopMode(next);
  }

  Future<void> dispose() async {
    await _persistSession();
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _player.dispose();
    notifier.dispose();
  }

  void _bindPlayer() {
    _subscriptions.add(
      _player.currentIndexStream.listen((index) async {
        notifier.value = notifier.value.copyWith(
          currentIndex: index,
          duration: _player.duration,
        );
        final track = notifier.value.currentTrack;
        if (track != null) {
          await _libraryRepository.addToHistory(track);
        }
        await _persistSession();
      }),
    );
    _subscriptions.add(
      _player.positionStream.listen((position) {
        notifier.value = notifier.value.copyWith(position: position);
      }),
    );
    _subscriptions.add(
      _player.bufferedPositionStream.listen((position) {
        notifier.value = notifier.value.copyWith(bufferedPosition: position);
      }),
    );
    _subscriptions.add(
      _player.durationStream.listen((duration) {
        notifier.value = notifier.value.copyWith(duration: duration);
      }),
    );
    _subscriptions.add(
      _player.playerStateStream.listen((state) {
        AppLogger.instance.d(
          'Player state changed: playing=${state.playing}, '
          'processing=${state.processingState.name}, '
          'index=${_player.currentIndex}, '
          'positionMs=${_player.position.inMilliseconds}',
        );
        notifier.value = notifier.value.copyWith(
          isPlaying: state.playing,
          isBuffering:
              state.processingState == ProcessingState.buffering ||
              state.processingState == ProcessingState.loading,
        );
      }),
    );
    _subscriptions.add(
      _player.loopModeStream.listen((mode) {
        notifier.value = notifier.value.copyWith(loopMode: mode);
      }),
    );
    _subscriptions.add(
      _player.shuffleModeEnabledStream.listen((enabled) {
        notifier.value = notifier.value.copyWith(shuffleEnabled: enabled);
      }),
    );
    _subscriptions.add(
      _player.errorStream.listen((error) {
        AppLogger.instance.e(
          'Playback engine error: ${error.message}',
          error: error,
        );
        notifier.value = notifier.value.copyWith(
          error: 'Playback stopped unexpectedly. Please retry this track.',
        );
      }),
    );
  }

  Future<void> _restoreSession() async {
    if (!_settingsRepository.current.rememberQueue) {
      return;
    }
    final queueJson = _prefs.getString(_queueKey);
    if (queueJson == null || queueJson.isEmpty) {
      return;
    }
    final rawQueue = jsonDecode(queueJson) as List<dynamic>;
    final queue = rawQueue
        .map((item) => Track.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
    final index = _prefs.getInt(_indexKey) ?? 0;
    final positionMs = _prefs.getInt(_positionKey) ?? 0;
    final playing = _prefs.getBool(_playingKey) ?? false;
    await setQueue(
      queue,
      initialIndex: index,
      initialPosition: Duration(milliseconds: positionMs),
      autoplay: false,
      bypassRoomLock: true,
    );
    if (playing) {
      _launchPlayRequest();
    }
  }

  Future<void> _persistSession() async {
    if (!_settingsRepository.current.rememberQueue || snapshot.queue.isEmpty) {
      return;
    }
    await _prefs.setString(
      _queueKey,
      jsonEncode(snapshot.queue.map((track) => track.toJson()).toList()),
    );
    await _prefs.setInt(_indexKey, snapshot.currentIndex ?? 0);
    await _prefs.setInt(_positionKey, snapshot.position.inMilliseconds);
    await _prefs.setBool(_playingKey, snapshot.isPlaying);
  }

  Future<Uri?> _resolveTrackUri(Track track) async {
    if (track.isAurexSource) {
      final inMemoryUrl = track.bestAudioUrl(AudioQuality.kbps160);
      if (inMemoryUrl != null) {
        return Uri.tryParse(inMemoryUrl);
      }
      final uri = await _ref
          .read(aurexApiClientProvider)
          .resolveTrackUri(track);
      AppLogger.instance.d(
        'Resolved Aurex fallback audio for ${track.id}: ${uri ?? 'none'}',
      );
      return uri;
    }

    final download = await _libraryRepository.getDownload(track.id);
    if (download != null && await fileExists(download.localPath)) {
      AppLogger.instance.d(
        'Resolved local download for track ${track.id}: ${download.localPath}',
      );
      return Uri.file(download.localPath);
    }
    if (download != null) {
      await _libraryRepository.removeDownload(track.id);
    }

    final effectiveQuality = _settingsRepository.current.autoQuality
        ? AudioQuality.kbps160
        : _settingsRepository.current.streamingQuality;
    final url = track.bestAudioUrl(effectiveQuality);
    AppLogger.instance.d(
      'Resolved remote audio for track ${track.id} (${track.title}) '
      'at quality=${effectiveQuality.key}: ${url ?? 'none'}',
    );
    return url == null ? null : Uri.parse(url);
  }

  Future<void> _ensureNotificationPermission() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    final status = await Permission.notification.status;
    if (!status.isGranted) {
      await Permission.notification.request();
    }
  }

  bool _canControl(bool bypassRoomLock) {
    if (bypassRoomLock) {
      return true;
    }
    final roomSession = _ref.read(roomSessionControllerProvider);
    if (!roomSession.controlsLocked) {
      return true;
    }
    notifier.value = notifier.value.copyWith(
      error: roomPlaybackLockedMessage(roomSession),
    );
    return false;
  }
}
