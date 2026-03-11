// ignore_for_file: avoid_print, depend_on_referenced_packages

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:supabase/supabase.dart';

Future<void> main() async {
  final env = _loadEnvFile('.env');
  final url = env['SUPABASE_URL']?.trim();
  final key = (env['SUPABASE_PUBLISHABLE_KEY'] ?? env['SUPABASE_ANON_KEY'])
      ?.trim();

  if (url == null || url.isEmpty || key == null || key.isEmpty) {
    throw StateError('Supabase URL or publishable key is missing.');
  }

  final stamp = DateTime.now().millisecondsSinceEpoch;
  final password = 'AurexRealtime!$stamp';
  final authOptions = const AuthClientOptions(
    autoRefreshToken: false,
    authFlowType: AuthFlowType.implicit,
  );

  final host = SupabaseClient(url, key, authOptions: authOptions);
  final listener = SupabaseClient(url, key, authOptions: authOptions);

  try {
    final hostEmail = 'realtime.host.$stamp@example.com';
    final listenerEmail = 'realtime.listener.$stamp@example.com';

    await host.auth.signUp(email: hostEmail, password: password);
    await listener.auth.signUp(email: listenerEmail, password: password);

    final immediateResult = await _runProbe(
      host: host,
      listener: listener,
      tag: 'immediate',
      waitForInitialRows: false,
      settleDelay: Duration.zero,
    );

    final warmResult = await _runProbe(
      host: host,
      listener: listener,
      tag: 'warm',
      waitForInitialRows: true,
      settleDelay: const Duration(seconds: 4),
    );

    print(
      const JsonEncoder.withIndent(
        '  ',
      ).convert({'immediate': immediateResult, 'warm': warmResult}),
    );
  } finally {
    await host.dispose();
    await listener.dispose();
  }
}

Future<Map<String, Object?>> _runProbe({
  required SupabaseClient host,
  required SupabaseClient listener,
  required String tag,
  required bool waitForInitialRows,
  required Duration settleDelay,
}) async {
  final room = Map<String, dynamic>.from(
    await host.rpc('create_room', params: {'p_name': 'Realtime Probe $tag'})
        as Map,
  );
  final roomId = room['id'] as String;
  final roomCode = room['code'] as String;
  await listener.rpc('join_room', params: {'p_code': roomCode});

  final now = DateTime.now().millisecondsSinceEpoch;
  final message = '$tag-message-$now';
  final sequence = now % 100000;

  final roomStream = host
      .from('rooms')
      .stream(primaryKey: ['id'])
      .eq('id', roomId);
  final messageStream = host
      .from('room_messages')
      .stream(primaryKey: ['id'])
      .eq('room_id', roomId)
      .order('created_at');
  final playbackStream = listener
      .from('room_playback_states')
      .stream(primaryKey: ['room_id'])
      .eq('room_id', roomId);

  final roomEvent = _firstMatch<List<Map<String, dynamic>>>(
    roomStream,
    (rows) =>
        rows.any((row) => row['host_user_id'] == listener.auth.currentUser?.id),
  );
  final messageEvent = _firstMatch<List<Map<String, dynamic>>>(
    messageStream,
    (rows) => rows.any((row) => row['message'] == message),
  );
  final playbackEvent = _firstMatch<List<Map<String, dynamic>>>(
    playbackStream,
    (rows) => rows.any((row) => row['sequence'] == sequence),
  );

  if (waitForInitialRows) {
    await Future.wait<void>([
      roomStream.first.timeout(const Duration(seconds: 20)).then((_) {}),
      messageStream.first.timeout(const Duration(seconds: 20)).then((_) {}),
      playbackStream.first.timeout(const Duration(seconds: 20)).then((_) {}),
    ]);
  }

  if (settleDelay > Duration.zero) {
    await Future<void>.delayed(settleDelay);
  }

  await listener.from('room_messages').insert({
    'room_id': roomId,
    'user_id': listener.auth.currentUser!.id,
    'display_name': listener.auth.currentUser!.email ?? 'listener',
    'message': message,
    'kind': 'message',
  });

  await host.from('room_playback_states').upsert({
    'room_id': roomId,
    'host_user_id': host.auth.currentUser!.id,
    'track_json': {'id': 'track-$sequence', 'title': 'Realtime Probe Track'},
    'queue_json': [
      {'id': 'track-$sequence', 'title': 'Realtime Probe Track'},
    ],
    'queue_index': 0,
    'position_ms': 5000,
    'is_playing': true,
    'sequence': sequence,
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  });

  await host.rpc(
    'transfer_room_host',
    params: {
      'p_room_id': roomId,
      'p_new_host_user_id': listener.auth.currentUser!.id,
    },
  );

  final roomDelivered = await _awaitBool(
    roomEvent.then(
      (rows) => rows.any(
        (row) => row['host_user_id'] == listener.auth.currentUser?.id,
      ),
    ),
  );
  final messageDelivered = await _awaitBool(
    messageEvent.then((rows) => rows.any((row) => row['message'] == message)),
  );
  final playbackDelivered = await _awaitBool(
    playbackEvent.then(
      (rows) => rows.any((row) => row['sequence'] == sequence),
    ),
  );

  final directRoom = Map<String, dynamic>.from(
    await host.from('rooms').select('host_user_id').eq('id', roomId).single(),
  );
  final directMessages = List<Map<String, dynamic>>.from(
    await host
        .from('room_messages')
        .select('message')
        .eq('room_id', roomId)
        .order('created_at'),
  );
  final directPlayback = Map<String, dynamic>.from(
    await host
        .from('room_playback_states')
        .select('sequence, host_user_id')
        .eq('room_id', roomId)
        .single(),
  );

  return {
    'roomId': roomId,
    'roomCode': roomCode,
    'waitForInitialRows': waitForInitialRows,
    'settleDelayMs': settleDelay.inMilliseconds,
    'messageDelivered': messageDelivered,
    'playbackDelivered': playbackDelivered,
    'hostTransferDelivered': roomDelivered,
    'directMessagePersisted': directMessages.any(
      (row) => row['message'] == message,
    ),
    'directPlaybackPersisted': directPlayback['sequence'] == sequence,
    'directHostUserId': directRoom['host_user_id'],
  };
}

Future<bool> _awaitBool(Future<bool> future) async {
  try {
    return await future.timeout(const Duration(seconds: 20));
  } catch (_) {
    return false;
  }
}

Future<T> _firstMatch<T>(
  Stream<T> stream,
  bool Function(T event) matches,
) async {
  late final StreamSubscription<T> subscription;
  final completer = Completer<T>();
  unawaited(
    completer.future.then<void>((_) {}, onError: (Object _, StackTrace _) {}),
  );

  subscription = stream.listen(
    (event) {
      if (!completer.isCompleted && matches(event)) {
        completer.complete(event);
      }
    },
    onError: (Object error, StackTrace stackTrace) {
      if (!completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
    },
  );

  try {
    return await completer.future;
  } finally {
    await subscription.cancel();
  }
}

Map<String, String> _loadEnvFile(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    return const <String, String>{};
  }

  final values = <String, String>{};
  for (final rawLine in file.readAsLinesSync()) {
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith('#') || !line.contains('=')) {
      continue;
    }
    final split = line.indexOf('=');
    final key = line.substring(0, split).trim();
    final value = line.substring(split + 1).trim();
    values[key] = value;
  }
  return values;
}
