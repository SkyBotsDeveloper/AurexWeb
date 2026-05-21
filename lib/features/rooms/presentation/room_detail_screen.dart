import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/utils/error_messages.dart';
import '../../../core/widgets/state_scaffold.dart';
import '../../player/data/playback_controller.dart';
import '../../player/data/playback_models.dart';
import '../data/room_models.dart';
import '../data/room_repository.dart';
import '../data/room_session_controller.dart';

final roomProvider = StreamProvider.family<RoomSummary?, String>(
  (ref, roomId) => ref.watch(roomRepositoryProvider).watchRoom(roomId),
);
final roomMembersProvider = StreamProvider.family<List<RoomMember>, String>(
  (ref, roomId) => ref.watch(roomRepositoryProvider).watchMembers(roomId),
);
final roomMessagesProvider = StreamProvider.family<List<RoomMessage>, String>(
  (ref, roomId) => ref.watch(roomRepositoryProvider).watchMessages(roomId),
);
final roomPlaybackProvider = StreamProvider.family<RoomPlaybackState?, String>(
  (ref, roomId) => ref.watch(roomRepositoryProvider).watchPlaybackState(roomId),
);

class RoomDetailScreen extends ConsumerStatefulWidget {
  const RoomDetailScreen({super.key, required this.roomId});

  final String roomId;

  @override
  ConsumerState<RoomDetailScreen> createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends ConsumerState<RoomDetailScreen> {
  final _messageController = TextEditingController();
  ProviderSubscription<AsyncValue<RoomSummary?>>? _roomSubscription;
  ProviderSubscription<AsyncValue<List<RoomMember>>>? _membersSubscription;
  RoomSummary? _latestRoom;
  List<RoomMember>? _latestMembers;
  bool _sessionSyncScheduled = false;

  @override
  void initState() {
    super.initState();
    _bindRoomListeners();
  }

  @override
  void didUpdateWidget(covariant RoomDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.roomId != widget.roomId) {
      _roomSubscription?.close();
      _membersSubscription?.close();
      _latestRoom = null;
      _latestMembers = null;
      _sessionSyncScheduled = false;
      _bindRoomListeners();
    }
  }

  @override
  void dispose() {
    _roomSubscription?.close();
    _membersSubscription?.close();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final room = ref.watch(roomProvider(widget.roomId));
    final members = ref.watch(roomMembersProvider(widget.roomId));
    final messages = ref.watch(roomMessagesProvider(widget.roomId));
    final playback = ref.watch(roomPlaybackProvider(widget.roomId));
    final playbackController = ref.watch(playbackControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Room'),
        actions: [
          IconButton(
            onPressed: room.asData?.value == null
                ? null
                : () => _shareRoom(room.asData!.value!),
            icon: const Icon(Icons.share_rounded),
          ),
          IconButton(
            onPressed: _leaveRoom,
            icon: const Icon(Icons.exit_to_app_rounded),
          ),
        ],
      ),
      body: room.when(
        data: (roomData) {
          if (roomData == null) {
            return const StateScaffold(
              icon: Icons.groups_outlined,
              title: 'Room not found',
              message:
                  'This room may have ended or the code is no longer active.',
            );
          }

          final currentUserId = ref.read(roomRepositoryProvider).currentUserId;

          return members.when(
            data: (memberList) {
              final currentMember = memberList.firstWhere(
                (member) => member.userId == currentUserId,
                orElse: () => RoomMember(
                  id: '',
                  roomId: roomData.id,
                  userId: currentUserId,
                  displayName: 'Listener',
                  role: 'listener',
                  joinedAt: DateTime.now(),
                  leftAt: null,
                ),
              );
              final isHost = currentMember.isHost;
              final playbackValue = playback.asData?.value;

              return Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                      children: [
                        Text(
                          roomData.name,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Code: ${roomData.code} / ${memberList.length}/${roomData.maxUsers} listeners',
                        ),
                        const SizedBox(height: 20),
                        ValueListenableBuilder<PlaybackSnapshot>(
                          valueListenable: playbackController.notifier,
                          builder: (context, localPlayback, child) {
                            final display = _resolveRoomPlaybackDisplay(
                              remotePlayback: playbackValue,
                              localPlayback: localPlayback,
                              isHost: isHost,
                            );
                            return _RoomPlaybackCard(display: display);
                          },
                        ),
                        if (isHost)
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              FilledButton.icon(
                                onPressed: () => ref
                                    .read(roomRepositoryProvider)
                                    .syncPlayback(
                                      widget.roomId,
                                      ref
                                          .read(playbackControllerProvider)
                                          .snapshot,
                                    ),
                                icon: const Icon(Icons.sync_rounded),
                                label: const Text('Force Sync'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => _showTransferHostDialog(
                                  context,
                                  memberList
                                      .where(
                                        (member) =>
                                            member.userId != currentUserId,
                                      )
                                      .toList(),
                                ),
                                icon: const Icon(
                                  Icons.admin_panel_settings_outlined,
                                ),
                                label: const Text('Transfer Host'),
                              ),
                            ],
                          ),
                        const SizedBox(height: 24),
                        Text(
                          'Members',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        ...memberList.map(
                          (member) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              member.isHost
                                  ? Icons.workspace_premium_rounded
                                  : Icons.person_outline_rounded,
                            ),
                            title: Text(member.displayName),
                            subtitle: Text(member.role),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Chat',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        messages.when(
                          data: (messageList) => Column(
                            children: messageList
                                .map(
                                  (message) => ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: Icon(
                                      message.kind == 'system'
                                          ? Icons.info_outline_rounded
                                          : Icons.chat_bubble_outline_rounded,
                                    ),
                                    title: Text(
                                      message.kind == 'system'
                                          ? 'Room update'
                                          : message.displayName,
                                    ),
                                    subtitle: Text(
                                      message.kind == 'system'
                                          ? '${message.displayName} ${message.message}'
                                          : message.message,
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                          loading: () => const Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(),
                          ),
                          error: (error, _) =>
                              Text(friendlyErrorMessage(error)),
                        ),
                      ],
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              decoration: const InputDecoration(
                                hintText: 'Send a message',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          FilledButton(
                            onPressed: () async {
                              final text = _messageController.text.trim();
                              if (text.isEmpty) {
                                return;
                              }
                              await ref
                                  .read(roomRepositoryProvider)
                                  .sendMessage(widget.roomId, text);
                              _messageController.clear();
                            },
                            child: const Icon(Icons.send_rounded),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => StateScaffold(
              icon: Icons.error_outline_rounded,
              title: 'Room members error',
              message: friendlyErrorMessage(error),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => StateScaffold(
          icon: Icons.error_outline_rounded,
          title: 'Room error',
          message: friendlyErrorMessage(error),
        ),
      ),
    );
  }

  Future<void> _leaveRoom() async {
    await ref.read(roomRepositoryProvider).leaveRoom(widget.roomId);
    ref.read(roomSessionControllerProvider.notifier).clear();
    if (mounted) {
      Navigator.of(context).maybePop();
    }
  }

  void _bindRoomListeners() {
    _roomSubscription = ref.listenManual<AsyncValue<RoomSummary?>>(
      roomProvider(widget.roomId),
      (_, next) {
        _latestRoom = next.asData?.value;
        _scheduleRoomSessionSync();
      },
      fireImmediately: true,
    );
    _membersSubscription = ref.listenManual<AsyncValue<List<RoomMember>>>(
      roomMembersProvider(widget.roomId),
      (_, next) {
        _latestMembers = next.asData?.value;
        _scheduleRoomSessionSync();
      },
      fireImmediately: true,
    );
  }

  void _scheduleRoomSessionSync() {
    if (_sessionSyncScheduled || !mounted) {
      return;
    }
    _sessionSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sessionSyncScheduled = false;
      if (!mounted) {
        return;
      }
      _syncRoomSessionState();
    });
  }

  void _syncRoomSessionState() {
    final room = _latestRoom;
    if (room == null) {
      ref.read(roomSessionControllerProvider.notifier).clear();
      return;
    }

    final currentUserId = ref.read(roomRepositoryProvider).currentUserId;
    final members = _latestMembers ?? const <RoomMember>[];
    final currentMember = members.firstWhere(
      (member) => member.userId == currentUserId,
      orElse: () => RoomMember(
        id: '',
        roomId: room.id,
        userId: currentUserId,
        displayName: 'Listener',
        role: 'listener',
        joinedAt: DateTime.now(),
        leftAt: null,
      ),
    );

    ref
        .read(roomSessionControllerProvider.notifier)
        .activate(room: room, isHost: currentMember.isHost);
  }

  Future<void> _showTransferHostDialog(
    BuildContext context,
    List<RoomMember> candidates,
  ) async {
    if (candidates.isEmpty) {
      return;
    }
    final result = await showDialog<RoomMember>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Transfer Host'),
        content: SizedBox(
          width: 320,
          child: ListView(
            shrinkWrap: true,
            children: candidates
                .map(
                  (member) => ListTile(
                    title: Text(member.displayName),
                    subtitle: Text(member.userId),
                    onTap: () => Navigator.of(context).pop(member),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );

    if (result != null) {
      await ref
          .read(roomRepositoryProvider)
          .transferHost(widget.roomId, result.userId);
    }
  }

  Future<void> _shareRoom(RoomSummary room) async {
    await SharePlus.instance.share(
      ShareParams(
        title: 'Join ${room.name}',
        text: 'Join ${room.name} on Aurex with room code ${room.code}.',
      ),
    );
  }
}

class _RoomPlaybackCard extends StatelessWidget {
  const _RoomPlaybackCard({required this.display});

  final _ResolvedRoomPlayback display;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.graphic_eq_rounded),
                const SizedBox(width: 8),
                Text(
                  'Now Playing',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(display.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              display.subtitle,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  avatar: Icon(display.statusIcon, size: 18),
                  label: Text(display.statusLabel),
                ),
                if (display.note != null && display.note!.isNotEmpty)
                  Chip(
                    avatar: Icon(
                      display.isSyncing
                          ? Icons.sync_problem_rounded
                          : Icons.headphones_rounded,
                      size: 18,
                    ),
                    label: Text(display.note!),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ResolvedRoomPlayback {
  const _ResolvedRoomPlayback({
    required this.title,
    required this.subtitle,
    required this.statusLabel,
    required this.statusIcon,
    required this.isSyncing,
    this.note,
  });

  final String title;
  final String subtitle;
  final String statusLabel;
  final IconData statusIcon;
  final bool isSyncing;
  final String? note;
}

_ResolvedRoomPlayback _resolveRoomPlaybackDisplay({
  required RoomPlaybackState? remotePlayback,
  required PlaybackSnapshot localPlayback,
  required bool isHost,
}) {
  final remoteTrack = remotePlayback?.currentTrack;
  final localTrack = localPlayback.currentTrack;
  final hasRemote = remoteTrack != null;
  final hasLocal = localTrack != null;
  final isMismatch = hasRemote && hasLocal && remoteTrack.id != localTrack.id;

  if (!hasRemote && !hasLocal) {
    return const _ResolvedRoomPlayback(
      title: 'No synced track',
      subtitle: 'Waiting for the host to start playback.',
      statusLabel: 'Idle',
      statusIcon: Icons.pause_circle_outline_rounded,
      isSyncing: false,
    );
  }

  if (!hasRemote && hasLocal) {
    return _ResolvedRoomPlayback(
      title: localTrack.title,
      subtitle: localTrack.artistNames,
      statusLabel: localPlayback.isPlaying
          ? 'Playing locally'
          : 'Ready locally',
      statusIcon: localPlayback.isPlaying
          ? Icons.play_circle_fill_rounded
          : Icons.pause_circle_outline_rounded,
      isSyncing: false,
      note: isHost
          ? 'Room update is being prepared.'
          : 'Waiting for room sync.',
    );
  }

  if (isMismatch && !isHost) {
    return _ResolvedRoomPlayback(
      title: remoteTrack.title,
      subtitle: remoteTrack.artistNames,
      statusLabel: (remotePlayback?.isPlaying ?? false)
          ? 'Syncing'
          : 'Paused by host',
      statusIcon: Icons.sync_rounded,
      isSyncing: true,
      note: 'Updating from ${localTrack.title}.',
    );
  }

  final displayTrack = isHost && hasLocal ? localTrack : remoteTrack;
  final isPlaying = isHost
      ? localPlayback.isPlaying
      : (remotePlayback?.isPlaying ?? false);

  return _ResolvedRoomPlayback(
    title: displayTrack?.title ?? 'No synced track',
    subtitle: displayTrack?.artistNames ?? 'Waiting for host sync',
    statusLabel: isPlaying ? 'Playing' : 'Paused',
    statusIcon: isPlaying
        ? Icons.play_circle_fill_rounded
        : Icons.pause_circle_outline_rounded,
    isSyncing: false,
    note: isHost
        ? 'Your playback controls the room.'
        : 'Listening to the host in sync.',
  );
}
