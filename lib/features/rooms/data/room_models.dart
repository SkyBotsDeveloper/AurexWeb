import '../../music/domain/music_models.dart';
import '../../../core/utils/json_utils.dart';

class RoomSummary {
  const RoomSummary({
    required this.id,
    required this.name,
    required this.code,
    required this.hostUserId,
    required this.isActive,
    required this.maxUsers,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String code;
  final String hostUserId;
  final bool isActive;
  final int maxUsers;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory RoomSummary.fromJson(Map<String, dynamic> json) => RoomSummary(
        id: readString(json['id']) ?? '',
        name: readString(json['name']) ?? 'Room',
        code: readString(json['code']) ?? '',
        hostUserId: readString(json['host_user_id']) ?? '',
        isActive: readBool(json['is_active'], fallback: true),
        maxUsers: readInt(json['max_users']) ?? 25,
        createdAt: DateTime.tryParse(readString(json['created_at']) ?? '') ??
            DateTime.now(),
        updatedAt: DateTime.tryParse(readString(json['updated_at']) ?? '') ??
            DateTime.now(),
      );
}

class RoomMember {
  const RoomMember({
    required this.id,
    required this.roomId,
    required this.userId,
    required this.displayName,
    required this.role,
    required this.joinedAt,
    required this.leftAt,
  });

  final String id;
  final String roomId;
  final String userId;
  final String displayName;
  final String role;
  final DateTime joinedAt;
  final DateTime? leftAt;

  bool get isHost => role == 'host';
  bool get isActive => leftAt == null;

  factory RoomMember.fromJson(Map<String, dynamic> json) => RoomMember(
        id: readString(json['id']) ?? '',
        roomId: readString(json['room_id']) ?? '',
        userId: readString(json['user_id']) ?? '',
        displayName: readString(json['display_name']) ?? 'Listener',
        role: readString(json['role']) ?? 'listener',
        joinedAt: DateTime.tryParse(readString(json['joined_at']) ?? '') ??
            DateTime.now(),
        leftAt: DateTime.tryParse(readString(json['left_at']) ?? ''),
      );
}

class RoomMessage {
  const RoomMessage({
    required this.id,
    required this.roomId,
    required this.userId,
    required this.displayName,
    required this.message,
    required this.kind,
    required this.createdAt,
  });

  final String id;
  final String roomId;
  final String userId;
  final String displayName;
  final String message;
  final String kind;
  final DateTime createdAt;

  factory RoomMessage.fromJson(Map<String, dynamic> json) => RoomMessage(
        id: readString(json['id']) ?? '',
        roomId: readString(json['room_id']) ?? '',
        userId: readString(json['user_id']) ?? '',
        displayName: readString(json['display_name']) ?? 'Listener',
        message: readString(json['message']) ?? '',
        kind: readString(json['kind']) ?? 'message',
        createdAt: DateTime.tryParse(readString(json['created_at']) ?? '') ??
            DateTime.now(),
      );
}

class RoomPlaybackState {
  const RoomPlaybackState({
    required this.roomId,
    required this.hostUserId,
    required this.queue,
    required this.queueIndex,
    required this.positionMs,
    required this.isPlaying,
    required this.sequence,
    required this.updatedAt,
  });

  final String roomId;
  final String hostUserId;
  final List<Track> queue;
  final int queueIndex;
  final int positionMs;
  final bool isPlaying;
  final int sequence;
  final DateTime updatedAt;

  Track? get currentTrack =>
      queueIndex >= 0 && queueIndex < queue.length ? queue[queueIndex] : null;

  factory RoomPlaybackState.fromJson(Map<String, dynamic> json) {
    final queueJson = json['queue_json'];
    final queue = queueJson is List
        ? queueJson
            .map((item) => Track.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList()
        : <Track>[];

    return RoomPlaybackState(
      roomId: readString(json['room_id']) ?? '',
      hostUserId: readString(json['host_user_id']) ?? '',
      queue: queue,
      queueIndex: readInt(json['queue_index']) ?? 0,
      positionMs: readInt(json['position_ms']) ?? 0,
      isPlaying: readBool(json['is_playing']),
      sequence: readInt(json['sequence']) ?? 0,
      updatedAt: DateTime.tryParse(readString(json['updated_at']) ?? '') ??
          DateTime.now(),
    );
  }
}
