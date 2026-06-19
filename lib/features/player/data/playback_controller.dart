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
import 'aurex_audio_cache_repository.dart';
import 'playback_models.dart';

final playbackControllerProvider = Provider<PlaybackController>((ref) {
  final controller = PlaybackController(
    ref,
    ref.watch(sharedPreferencesProvider),
    ref.watch(libraryRepositoryProvider),
    ref.watch(settingsRepositoryProvider),
    ref.watch(aurexAudioCacheRepositoryProvider),
  );
  ref.onDispose(() {
    unawaited(controller.dispose());
  });
  return controller;
});

enum _AurexResumeRefreshResult { notNeeded, refreshed, failed }

class PlaybackController {
  PlaybackController(
    this._ref,
    this._prefs,
    this._libraryRepository,
    this._settingsRepository,
    this._aurexAudioCacheRepository,
  ) : _player = AudioPlayer() {
    _bindPlayer();
    unawaited(_restoreSession());
  }

  final Ref _ref;
  final SharedPreferences _prefs;
  final LibraryRepository _libraryRepository;
  final SettingsRepository _settingsRepository;
  final AurexAudioCacheRepository _aurexAudioCacheRepository;
  final AudioPlayer _player;
  final ValueNotifier<PlaybackSnapshot> notifier = ValueNotifier(
    const PlaybackSnapshot(),
  );
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Future<void> _queueOperation = Future.value();
  int _queueRequestVersion = 0;
  DateTime? _pausedAt;
  Future<void>? _resumeOperation;
  final Map<String, DateTime> _aurexStreamResolvedAt = {};

  static const _queueKey = 'playback.queue';
  static const _indexKey = 'playback.index';
  static const _positionKey = 'playback.position_ms';
  static const _playingKey = 'playback.playing';
  static const _aurexResumeRefreshAfter = Duration(seconds: 25);

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
    String? initialTrackId,
    Duration initialPosition = Duration.zero,
    bool autoplay = true,
    bool bypassRoomLock = false,
    int? forceAurexRefreshIndex,
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
            initialTrackId: initialTrackId,
            initialPosition: initialPosition,
            autoplay: autoplay,
            forceAurexRefreshIndex: forceAurexRefreshIndex,
            requestVersion: requestVersion,
          ),
        );
    await _queueOperation;
  }

  Future<void> _performSetQueue(
    List<Track> queue, {
    required int initialIndex,
    String? initialTrackId,
    required Duration initialPosition,
    required bool autoplay,
    int? forceAurexRefreshIndex,
    required int requestVersion,
  }) async {
    if (requestVersion != _queueRequestVersion) {
      return;
    }

    await _ensureNotificationPermission();

    final sources = <AudioSource>[];
    final playableTracks = <Track>[];
    final resolvedUris = <Uri>[];

    for (var sourceIndex = 0; sourceIndex < queue.length; sourceIndex++) {
      final track = queue[sourceIndex];
      Uri? uri;
      try {
        uri = await _resolveTrackUri(
          track,
          forceAurexRefresh: sourceIndex == forceAurexRefreshIndex,
        );
      } catch (error, stackTrace) {
        if (initialTrackId == null || track.id == initialTrackId) {
          rethrow;
        }
        AppLogger.instance.w(
          'Skipping related queue track after source resolution failed',
          error: error,
          stackTrace: stackTrace,
        );
        continue;
      }
      if (uri == null) {
        AppLogger.instance.w(
          'Skipping unplayable track because no audio source was resolved',
          error: track.title,
        );
        continue;
      }
      playableTracks.add(track);
      resolvedUris.add(uri);
      sources.add(_audioSourceForTrack(track, uri));
    }

    if (requestVersion != _queueRequestVersion) {
      return;
    }

    if (sources.isEmpty) {
      throw StateError(
        'This track is not playable right now. Try another song or retry in a moment.',
      );
    }

    var safeIndex = initialIndex.clamp(0, playableTracks.length - 1);
    if (initialTrackId != null) {
      final selectedIndex = playableTracks.indexWhere(
        (track) => track.id == initialTrackId,
      );
      if (selectedIndex < 0) {
        throw StateError(
          'The selected song is not playable right now. Please try another result.',
        );
      }
      safeIndex = selectedIndex;
    }
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

    if (autoplay) {
      final started = await _playPreparedQueue(
        initialPosition: initialPosition,
        requestVersion: requestVersion,
      );
      if (requestVersion != _queueRequestVersion) {
        return;
      }
      notifier.value = notifier.value.copyWith(
        isPlaying: started,
        isBuffering: started ? notifier.value.isBuffering : false,
      );
      if (started) {
        _cacheSelectedAurexTrack(
          playableTracks[safeIndex],
          resolvedUris[safeIndex],
        );
      }
    }
    await _persistSession();
  }

  Future<void> _resetPlaybackForReplacement() async {
    if (_player.playing) {
      AppLogger.instance.d('Pausing active playback before queue replacement');
      await _player.pause();
    }
    AppLogger.instance.d('Stopping player before queue replacement');
    await _player.stop();
  }

  Future<bool> _playPreparedQueue({
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
    return started;
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
        AppLogger.instance.d(
          'Playback start confirmed before retry for requestVersion=$requestVersion',
        );
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
        AppLogger.instance.i(
          'Playback start confirmed for requestVersion=$requestVersion '
          'at ${_player.position.inMilliseconds}ms',
        );
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

    final activeResume = _resumeOperation;
    if (activeResume != null) {
      AppLogger.instance.d('Ignoring repeated play tap while resume is active');
      await activeResume;
      return;
    }

    if (_player.playing) {
      final requestedPosition = _player.position;
      AppLogger.instance.i(
        'Pausing playback at ${requestedPosition.inMilliseconds}ms',
      );
      await _player.pause();
      final pausedPosition = _player.position;
      _pausedAt = DateTime.now();
      notifier.value = notifier.value.copyWith(
        position: pausedPosition,
        isPlaying: false,
        isBuffering: false,
        isResuming: false,
      );
      AppLogger.instance.i(
        'Playback pause confirmed at ${pausedPosition.inMilliseconds}ms',
      );
      await _persistSession();
    } else {
      await _runResumeOperation(reason: 'user');
    }
  }

  Future<void> _runResumeOperation({
    required String reason,
    bool forceAurexRefresh = false,
  }) async {
    final activeResume = _resumeOperation;
    if (activeResume != null) {
      AppLogger.instance.d(
        'Joining active resume operation instead of starting another; '
        'reason=$reason',
      );
      await activeResume;
      return;
    }

    final operation = _resumePlayback(
      reason: reason,
      forceAurexRefresh: forceAurexRefresh,
    );
    _resumeOperation = operation;
    try {
      await operation;
    } catch (error, stackTrace) {
      notifier.value = notifier.value.copyWith(
        isPlaying: false,
        isBuffering: false,
        error: friendlyErrorMessage(
          error,
          fallback: 'Could not resume this song. Please try again.',
        ),
      );
      AppLogger.instance.e(
        'Guarded playback resume threw an unexpected error; reason=$reason',
        error: error,
        stackTrace: stackTrace,
      );
      await _persistSession();
    } finally {
      if (identical(_resumeOperation, operation)) {
        _resumeOperation = null;
        notifier.value = notifier.value.copyWith(isResuming: false);
      }
    }
  }

  Future<void> _resumePlayback({
    required String reason,
    required bool forceAurexRefresh,
  }) async {
    final resumePosition = _player.position;
    final requestVersion = _queueRequestVersion;
    final currentTrack = snapshot.currentTrack;
    notifier.value = notifier.value.copyWith(
      isResuming: true,
      clearError: true,
    );
    AppLogger.instance.i(
      'Starting guarded playback resume; reason=$reason; '
      'track=${currentTrack?.id ?? 'none'}; '
      'positionMs=${resumePosition.inMilliseconds}; '
      'requestVersion=$requestVersion',
    );

    var refreshResult = await _refreshCurrentAurexSourceForResume(
      force: forceAurexRefresh,
      resumePosition: resumePosition,
    );
    var started = refreshResult == _AurexResumeRefreshResult.refreshed
        ? _player.playing
        : false;

    if (refreshResult == _AurexResumeRefreshResult.notNeeded) {
      started = await _ensurePlaybackStarted(
        requestVersion: requestVersion,
        initialPosition: resumePosition,
      );

      if (!started && currentTrack?.isAurexSource == true) {
        AppLogger.instance.w(
          'Aurex resume did not start with the current source; '
          'forcing one stream refresh',
        );
        refreshResult = await _refreshCurrentAurexSourceForResume(
          force: true,
          resumePosition: resumePosition,
        );
        started =
            refreshResult == _AurexResumeRefreshResult.refreshed &&
            _player.playing;
      }
    }

    if (started) {
      _pausedAt = null;
      notifier.value = notifier.value.copyWith(
        position: _player.position,
        isPlaying: true,
        clearError: true,
      );
      AppLogger.instance.i(
        'Guarded playback resume confirmed; reason=$reason; '
        'positionMs=${_player.position.inMilliseconds}; '
        'processing=${_player.processingState.name}',
      );
    } else {
      notifier.value = notifier.value.copyWith(
        isPlaying: false,
        isBuffering: false,
        error: 'Could not resume this song. Please try again.',
      );
      AppLogger.instance.w(
        'Guarded playback resume failed; reason=$reason; '
        'refreshResult=${refreshResult.name}; '
        'processing=${_player.processingState.name}',
      );
    }
    await _persistSession();
  }

  Future<void> appendToQueue(
    List<Track> tracks, {
    required String expectedCurrentTrackId,
    bool bypassRoomLock = false,
  }) async {
    if (!_canControl(bypassRoomLock) || tracks.isEmpty) {
      return;
    }

    final requestVersion = _queueRequestVersion;
    _queueOperation = _queueOperation
        .catchError((_) {})
        .then(
          (_) => _performAppendToQueue(
            tracks,
            expectedCurrentTrackId: expectedCurrentTrackId,
            requestVersion: requestVersion,
          ),
        );
    await _queueOperation;
  }

  Future<void> _performAppendToQueue(
    List<Track> tracks, {
    required String expectedCurrentTrackId,
    required int requestVersion,
  }) async {
    if (requestVersion != _queueRequestVersion ||
        snapshot.currentTrack?.id != expectedCurrentTrackId) {
      return;
    }

    final existingIds = snapshot.queue.map((track) => track.id).toSet();
    final appendedIds = <String>{};
    final playableTracks = <Track>[];
    final sources = <AudioSource>[];

    for (final track in tracks) {
      if (existingIds.contains(track.id) || !appendedIds.add(track.id)) {
        continue;
      }
      if (requestVersion != _queueRequestVersion ||
          snapshot.currentTrack?.id != expectedCurrentTrackId) {
        return;
      }
      try {
        final uri = await _resolveTrackUri(track);
        if (uri == null) {
          continue;
        }
        playableTracks.add(track);
        sources.add(_audioSourceForTrack(track, uri));
      } catch (error, stackTrace) {
        AppLogger.instance.w(
          'Skipping unplayable search queue suggestion',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    if (sources.isEmpty ||
        requestVersion != _queueRequestVersion ||
        snapshot.currentTrack?.id != expectedCurrentTrackId) {
      return;
    }

    await _player.addAudioSources(sources);
    if (requestVersion != _queueRequestVersion) {
      return;
    }
    notifier.value = notifier.value.copyWith(
      queue: List.unmodifiable([...snapshot.queue, ...playableTracks]),
    );
    AppLogger.instance.i(
      'Appended ${playableTracks.length} search suggestion(s) to queue; '
      'anchor=$expectedCurrentTrackId',
    );
    await _persistSession();
  }

  AudioSource _audioSourceForTrack(Track track, Uri uri) {
    return AudioSource.uri(
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
    );
  }

  Future<void> playAtIndex(int index, {bool bypassRoomLock = false}) async {
    if (!_canControl(bypassRoomLock)) {
      return;
    }
    if (snapshot.queue.isEmpty) {
      return;
    }

    final safeIndex = index.clamp(0, snapshot.queue.length - 1);
    final targetTrack = snapshot.queue[safeIndex];
    if (targetTrack.isAurexSource && _shouldRefreshAurexTrack(targetTrack)) {
      await setQueue(
        snapshot.queue,
        initialIndex: safeIndex,
        initialPosition: Duration.zero,
        autoplay: true,
        bypassRoomLock: true,
        forceAurexRefreshIndex: safeIndex,
      );
      await _persistSession();
      return;
    }

    await _player.seek(Duration.zero, index: safeIndex);
    notifier.value = notifier.value.copyWith(
      currentIndex: safeIndex,
      position: Duration.zero,
      duration: targetTrack.duration,
      clearError: true,
    );
    _launchPlayRequest();
    final selectedUri = targetTrack.bestAudioUrl(AudioQuality.kbps160);
    if (selectedUri != null) {
      final parsedUri = Uri.tryParse(selectedUri);
      if (parsedUri != null) {
        _cacheSelectedAurexTrack(targetTrack, parsedUri);
      }
    }
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
        if (state.playing) {
          _pausedAt = null;
        }
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
        final playbackWasExpected =
            notifier.value.isPlaying ||
            notifier.value.isResuming ||
            _player.playing;
        AppLogger.instance.e(
          'Playback engine error: ${error.message}',
          error: error,
        );
        notifier.value = notifier.value.copyWith(
          error: 'Playback stopped unexpectedly. Please retry this track.',
        );
        final track = notifier.value.currentTrack;
        if (track != null && track.isAurexSource && playbackWasExpected) {
          unawaited(
            _runResumeOperation(
              reason: 'aurex-engine-error',
              forceAurexRefresh: true,
            ),
          );
        }
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
      await _runResumeOperation(reason: 'session-restore');
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

  Future<_AurexResumeRefreshResult> _refreshCurrentAurexSourceForResume({
    bool force = false,
    required Duration resumePosition,
  }) async {
    final queue = snapshot.queue;
    if (queue.isEmpty) {
      return _AurexResumeRefreshResult.notNeeded;
    }
    final currentIndex = snapshot.currentIndex ?? _player.currentIndex;
    if (currentIndex == null ||
        currentIndex < 0 ||
        currentIndex >= queue.length) {
      return _AurexResumeRefreshResult.notNeeded;
    }
    final currentTrack = queue[currentIndex];
    if (!currentTrack.isAurexSource) {
      return _AurexResumeRefreshResult.notNeeded;
    }

    final shouldRefresh =
        _shouldRefreshAurexTrack(currentTrack, force: force) ||
        _player.processingState == ProcessingState.idle ||
        (_pausedAt != null &&
            DateTime.now().difference(_pausedAt!) >= _aurexResumeRefreshAfter);
    if (!shouldRefresh) {
      return _AurexResumeRefreshResult.notNeeded;
    }

    try {
      AppLogger.instance.i(
        'Refreshing Aurex stream before resume for ${currentTrack.id} '
        'at ${resumePosition.inMilliseconds}ms; index=$currentIndex; '
        'queueLength=${queue.length}; force=$force',
      );
      await setQueue(
        queue,
        initialIndex: currentIndex,
        initialPosition: resumePosition,
        autoplay: true,
        bypassRoomLock: true,
        forceAurexRefreshIndex: currentIndex,
      );
      if (!_player.playing) {
        AppLogger.instance.w(
          'Aurex stream refresh completed but playback was not confirmed',
        );
        return _AurexResumeRefreshResult.failed;
      }
      AppLogger.instance.i(
        'Aurex stream refresh and resume confirmed for ${currentTrack.id} '
        'at ${_player.position.inMilliseconds}ms',
      );
      return _AurexResumeRefreshResult.refreshed;
    } catch (error, stackTrace) {
      AppLogger.instance.e(
        'Failed to refresh Aurex stream before resume',
        error: error,
        stackTrace: stackTrace,
      );
      notifier.value = notifier.value.copyWith(
        error: friendlyErrorMessage(
          error,
          fallback: 'Could not resume this song. Please try again.',
        ),
      );
      return _AurexResumeRefreshResult.failed;
    }
  }

  bool _shouldRefreshAurexTrack(Track track, {bool force = false}) {
    if (force) {
      return true;
    }
    final resolvedAt = _aurexStreamResolvedAt[track.id];
    if (resolvedAt == null) {
      return true;
    }
    return DateTime.now().difference(resolvedAt) >= _aurexResumeRefreshAfter;
  }

  Future<Uri?> _resolveTrackUri(
    Track track, {
    bool forceAurexRefresh = false,
  }) async {
    if (track.isAurexSource) {
      final cachedUri = await _aurexAudioCacheRepository.getCachedUri(track);
      if (cachedUri != null) {
        _aurexStreamResolvedAt[track.id] = DateTime.now();
        return cachedUri;
      }
      final inMemoryUrl = forceAurexRefresh
          ? null
          : track.bestAudioUrl(AudioQuality.kbps160);
      if (inMemoryUrl != null) {
        _aurexStreamResolvedAt[track.id] = DateTime.now();
        return Uri.tryParse(inMemoryUrl);
      }
      final uri = await _ref
          .read(aurexApiClientProvider)
          .resolveTrackUri(track);
      AppLogger.instance.d(
        'Resolved Aurex fallback audio for ${track.id}: ${uri ?? 'none'}',
      );
      if (uri != null) {
        _aurexStreamResolvedAt[track.id] = DateTime.now();
      }
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

  void _cacheSelectedAurexTrack(Track track, Uri sourceUri) {
    if (!track.isAurexSource || sourceUri.scheme == 'file') {
      return;
    }
    unawaited(_aurexAudioCacheRepository.cacheResolvedTrack(track, sourceUri));
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
