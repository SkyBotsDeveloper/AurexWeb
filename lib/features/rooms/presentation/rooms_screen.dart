import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/error_messages.dart';
import '../../../core/widgets/glass_panel.dart';
import '../../../core/widgets/screen_intro_panel.dart';
import '../../../core/widgets/state_scaffold.dart';
import '../../auth/data/auth_repository.dart';
import '../data/room_repository.dart';
import '../data/room_session_controller.dart';

class RoomsScreen extends ConsumerStatefulWidget {
  const RoomsScreen({super.key});

  @override
  ConsumerState<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends ConsumerState<RoomsScreen> {
  final _roomNameController = TextEditingController();
  final _roomCodeController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _roomNameController.dispose();
    _roomCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final repo = ref.watch(roomRepositoryProvider);
    final roomSession = ref.watch(roomSessionControllerProvider);
    final bottomPadding = MediaQuery.sizeOf(context).width >= 1120
        ? 32.0
        : 140.0;

    if (!repo.isConfigured) {
      return const Scaffold(
        body: StateScaffold(
          icon: Icons.groups_outlined,
          title: 'Rooms unavailable',
          message:
              'Shared listening rooms are not ready right now. Complete room setup to enable syncing and chat.',
        ),
      );
    }

    return Scaffold(
      body: authState.when(
        data: (state) {
          if (!state.isSignedIn) {
            return StateScaffold(
              icon: Icons.lock_outline_rounded,
              title: 'Sign in to use rooms',
              message:
                  'Rooms require a signed-in identity for host permissions, membership, and chat.',
              action: FilledButton(
                onPressed: () => context.push('/auth'),
                child: const Text('Sign In'),
              ),
            );
          }

          return ListView(
            padding: EdgeInsets.fromLTRB(20, 24, 20, bottomPadding),
            children: [
              ScreenIntroPanel(
                compact: MediaQuery.sizeOf(context).width < 600,
                eyebrow: roomSession.hasActiveRoom
                    ? 'Room is active'
                    : 'Shared Rooms',
                title: roomSession.hasActiveRoom
                    ? 'Jump back into the room without losing the conversation.'
                    : 'Create or join a live listening room in one step.',
                description: roomSession.hasActiveRoom
                    ? 'Your room is already live. Open it to chat, keep everyone in sync, or manage host playback.'
                    : 'Create a host-led room or join with a code. Everyone stays on the same song while chat keeps moving in real time.',
              ),
              const SizedBox(height: 24),
              if (roomSession.hasActiveRoom) ...[
                GlassPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Active Room',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        roomSession.roomName ?? 'Shared Room',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Code: ${roomSession.roomCode ?? 'Unavailable'}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        roomSession.isHost
                            ? 'You are hosting. Songs you play anywhere in the app sync to the room.'
                            : 'You can browse the app, but only the host can change playback until you leave the room.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      FilledButton.tonalIcon(
                        onPressed: () =>
                            context.push('/room/${roomSession.roomId}'),
                        icon: const Icon(Icons.headphones_rounded),
                        label: const Text('Open Active Room'),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                GlassPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Create Room',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _roomNameController,
                        decoration: const InputDecoration(
                          hintText: 'Night Drive Session',
                          prefixIcon: Icon(Icons.meeting_room_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _busy
                            ? null
                            : () => _run(
                                asyncAction: () async {
                                  final room = await repo.createRoom(
                                    _roomNameController.text.trim().isEmpty
                                        ? 'Aurex Room'
                                        : _roomNameController.text.trim(),
                                  );
                                  ref
                                      .read(
                                        roomSessionControllerProvider.notifier,
                                      )
                                      .activate(room: room, isHost: true);
                                  if (!context.mounted) {
                                    return;
                                  }
                                  if (mounted) {
                                    context.push('/room/${room.id}');
                                  }
                                },
                              ),
                        child: const Text('Create & Enter'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                GlassPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Join Room',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _roomCodeController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          hintText: 'AB12CD',
                          prefixIcon: Icon(Icons.key_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.tonal(
                        onPressed: _busy
                            ? null
                            : () => _run(
                                asyncAction: () async {
                                  final room = await repo.joinRoom(
                                    _roomCodeController.text
                                        .trim()
                                        .toUpperCase(),
                                  );
                                  ref
                                      .read(
                                        roomSessionControllerProvider.notifier,
                                      )
                                      .activate(
                                        room: room,
                                        isHost:
                                            room.hostUserId ==
                                            repo.currentUserId,
                                      );
                                  if (!context.mounted) {
                                    return;
                                  }
                                  if (mounted) {
                                    context.push('/room/${room.id}');
                                  }
                                },
                              ),
                        child: const Text('Join by Code'),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => StateScaffold(
          icon: Icons.error_outline_rounded,
          title: 'Room auth error',
          message: friendlyErrorMessage(error),
        ),
      ),
    );
  }

  Future<void> _run({required Future<void> Function() asyncAction}) async {
    setState(() => _busy = true);
    try {
      await asyncAction();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(error))));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }
}
