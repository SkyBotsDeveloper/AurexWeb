import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'room_models.dart';

final roomSessionControllerProvider =
    NotifierProvider<RoomSessionController, RoomSessionState>(
  RoomSessionController.new,
);

class RoomSessionState {
  const RoomSessionState({
    this.roomId,
    this.roomName,
    this.roomCode,
    this.isHost = false,
  });

  final String? roomId;
  final String? roomName;
  final String? roomCode;
  final bool isHost;

  bool get hasActiveRoom => roomId != null && roomId!.isNotEmpty;
  bool get controlsLocked => hasActiveRoom && !isHost;
}

class RoomSessionController extends Notifier<RoomSessionState> {
  @override
  RoomSessionState build() => const RoomSessionState();

  void activate({
    required RoomSummary room,
    required bool isHost,
  }) {
    state = RoomSessionState(
      roomId: room.id,
      roomName: room.name,
      roomCode: room.code,
      isHost: isHost,
    );
  }

  void clear() {
    state = const RoomSessionState();
  }
}

String roomPlaybackLockedMessage(RoomSessionState state) {
  if (state.roomName != null && state.roomName!.isNotEmpty) {
    return 'Only the host can control playback in ${state.roomName}.';
  }
  return 'Only the room host can control playback.';
}
