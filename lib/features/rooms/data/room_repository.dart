import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_providers.dart';
import '../../player/data/playback_models.dart';
import 'room_models.dart';

final roomRepositoryProvider = Provider<RoomRepository>(
  (ref) => RoomRepository(ref.watch(supabaseClientProvider)),
);

class RoomRepository {
  RoomRepository(this._client);

  final SupabaseClient? _client;

  bool get isConfigured => _client != null;
  SupabaseClient get _requiredClient =>
      _client ??
      (throw const AuthException(
        'Shared listening rooms are not available right now.',
      ));

  String get currentUserId {
    final id = _client?.auth.currentUser?.id;
    if (id == null) {
      throw const AuthException('You must be signed in to use rooms.');
    }
    return id;
  }

  Future<RoomSummary> createRoom(String name) async {
    final client = _requiredClient;
    final response = await client.rpc('create_room', params: {'p_name': name});
    return RoomSummary.fromJson(Map<String, dynamic>.from(response as Map));
  }

  Future<RoomSummary> joinRoom(String code) async {
    final client = _requiredClient;
    final response = await client.rpc('join_room', params: {'p_code': code});
    return RoomSummary.fromJson(Map<String, dynamic>.from(response as Map));
  }

  Future<void> leaveRoom(String roomId) async {
    await _requiredClient.rpc('leave_room', params: {'p_room_id': roomId});
  }

  Future<void> transferHost(String roomId, String newHostUserId) async {
    await _requiredClient.rpc(
      'transfer_room_host',
      params: {
        'p_room_id': roomId,
        'p_new_host_user_id': newHostUserId,
      },
    );
  }

  Stream<RoomSummary?> watchRoom(String roomId) {
    return _requiredClient
        .from('rooms')
        .stream(primaryKey: ['id'])
        .eq('id', roomId)
        .map((rows) => rows.isEmpty ? null : RoomSummary.fromJson(rows.first));
  }

  Stream<List<RoomMember>> watchMembers(String roomId) {
    return _requiredClient
        .from('room_members')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .order('joined_at')
        .map(
          (rows) => rows
              .map(RoomMember.fromJson)
              .where((member) => member.leftAt == null)
              .toList(),
        );
  }

  Stream<List<RoomMessage>> watchMessages(String roomId) {
    return _requiredClient
        .from('room_messages')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .order('created_at')
        .map((rows) => rows.map(RoomMessage.fromJson).toList());
  }

  Stream<RoomPlaybackState?> watchPlaybackState(String roomId) {
    return _requiredClient
        .from('room_playback_states')
        .stream(primaryKey: ['room_id'])
        .eq('room_id', roomId)
        .map((rows) => rows.isEmpty ? null : RoomPlaybackState.fromJson(rows.first));
  }

  Future<void> sendMessage(String roomId, String message) async {
    final client = _requiredClient;
    final user = client.auth.currentUser;
    if (user == null) {
      throw const AuthException('You must be signed in to send messages.');
    }
    await client.from('room_messages').insert({
      'room_id': roomId,
      'user_id': user.id,
      'display_name': user.email ?? user.userMetadata?['full_name'] ?? 'Listener',
      'message': message,
      'kind': 'message',
    });
  }

  Future<void> syncPlayback(String roomId, PlaybackSnapshot snapshot) async {
    final client = _requiredClient;
    if (snapshot.queue.isEmpty) {
      return;
    }

    final current = await client
        .from('room_playback_states')
        .select()
        .eq('room_id', roomId)
        .maybeSingle();
    final nextSequence =
        current == null ? 1 : ((current['sequence'] as int?) ?? 0) + 1;

    await client.from('room_playback_states').upsert({
      'room_id': roomId,
      'host_user_id': currentUserId,
      'track_json': snapshot.currentTrack?.toJson(),
      'queue_json': snapshot.queue.map((track) => track.toJson()).toList(),
      'queue_index': snapshot.currentIndex ?? 0,
      'position_ms': snapshot.position.inMilliseconds,
      'is_playing': snapshot.isPlaying,
      'sequence': nextSequence,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<RoomMember?> currentMembership(String roomId) async {
    final client = _requiredClient;
    final userId = currentUserId;
    final row = await client
        .from('room_members')
        .select()
        .eq('room_id', roomId)
        .eq('user_id', userId)
        .isFilter('left_at', null)
        .maybeSingle();
    return row == null ? null : RoomMember.fromJson(row);
  }
}
