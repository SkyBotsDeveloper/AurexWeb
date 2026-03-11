import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/glass_panel.dart';
import '../../../core/widgets/state_scaffold.dart';
import '../../auth/data/auth_repository.dart';
import '../../rooms/data/room_session_controller.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final bottomPadding = MediaQuery.sizeOf(context).width >= 1120
        ? 32.0
        : 140.0;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: authState.when(
        data: (state) {
          if (!state.isConfigured) {
            return const StateScaffold(
              icon: Icons.person_outline_rounded,
              title: 'Profile unavailable',
              message:
                  'Your account area is not available right now. Finish app setup to enable profile and room identity features.',
            );
          }
          if (!state.isSignedIn) {
            return StateScaffold(
              icon: Icons.lock_outline_rounded,
              title: 'Sign in required',
              message:
                  'Your profile, playlists, and rooms become personalized once you sign in.',
              action: FilledButton(
                onPressed: () => context.push('/auth'),
                child: const Text('Sign In'),
              ),
            );
          }

          final user = state.user!;
          return ListView(
            padding: EdgeInsets.fromLTRB(20, 20, 20, bottomPadding),
            children: [
              GlassPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.email ?? 'Signed in',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'User ID: ${user.id}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Settings'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push('/settings'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('About Aurex'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push('/about'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Log Out'),
                trailing: const Icon(Icons.logout_rounded),
                onTap: () async {
                  ref.read(roomSessionControllerProvider.notifier).clear();
                  await ref.read(authRepositoryProvider).signOut();
                },
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => StateScaffold(
          icon: Icons.error_outline_rounded,
          title: 'Profile error',
          message: error.toString(),
        ),
      ),
    );
  }
}
