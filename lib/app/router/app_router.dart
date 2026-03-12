import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/ambient_background.dart';
import '../../core/widgets/app_bottom_nav.dart';
import '../../core/widgets/app_navigation_rail.dart';
import '../../core/widgets/glass_panel.dart';
import '../../features/about/presentation/about_screen.dart';
import '../../features/auth/presentation/auth_screen.dart';
import '../../features/auth/presentation/password_recovery_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/library/presentation/library_screen.dart';
import '../../features/music/presentation/artist_detail_screen.dart';
import '../../features/music/presentation/collection_detail_screen.dart';
import '../../features/music/presentation/song_detail_screen.dart';
import '../../features/player/data/playback_controller.dart';
import '../../features/player/data/playback_models.dart';
import '../../features/player/presentation/mini_player.dart';
import '../../features/player/presentation/player_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/rooms/presentation/room_detail_screen.dart';
import '../../features/rooms/presentation/rooms_screen.dart';
import '../../features/search/presentation/search_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/home',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            _AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/search',
                builder: (context, state) => const SearchScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/room',
                builder: (context, state) => const RoomsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/library',
                builder: (context, state) => const LibraryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(path: '/auth', builder: (context, state) => const AuthScreen()),
      GoRoute(
        path: '/auth/recovery',
        builder: (context, state) => const PasswordRecoveryScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(path: '/about', builder: (context, state) => const AboutScreen()),
      GoRoute(
        path: '/player',
        builder: (context, state) => const PlayerScreen(),
      ),
      GoRoute(
        path: '/album/:id',
        builder: (context, state) => CollectionDetailScreen(
          id: state.pathParameters['id']!,
          kind: CollectionKind.album,
        ),
      ),
      GoRoute(
        path: '/playlist/:id',
        builder: (context, state) => CollectionDetailScreen(
          id: state.pathParameters['id']!,
          kind: CollectionKind.playlist,
        ),
      ),
      GoRoute(
        path: '/artist/:id',
        builder: (context, state) =>
            ArtistDetailScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/song/:id',
        builder: (context, state) =>
            SongDetailScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/room/:id',
        builder: (context, state) =>
            RoomDetailScreen(roomId: state.pathParameters['id']!),
      ),
    ],
  );
});

class _AppShell extends ConsumerWidget {
  const _AppShell({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(playbackControllerProvider);
    final palette = AppColors.of(context);
    final viewport = MediaQuery.sizeOf(context);
    final width = viewport.width;
    final compactBottomChrome = width < 430 || viewport.height < 780;
    final wideLayout = width >= 1120;

    return ValueListenableBuilder<PlaybackSnapshot>(
      valueListenable: controller.notifier,
      builder: (context, snapshot, _) {
        final hasMiniPlayer = snapshot.currentTrack != null;
        final reservedBottomSpace = wideLayout
            ? 0.0
            : (hasMiniPlayer
                  ? (compactBottomChrome ? 144.0 : 158.0)
                  : (compactBottomChrome ? 82.0 : 92.0));

        if (wideLayout) {
          return Scaffold(
            body: AmbientBackground(
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppNavigationRail(
                        currentIndex: navigationShell.currentIndex,
                        onTap: (index) {
                          navigationShell.goBranch(
                            index,
                            initialLocation:
                                index == navigationShell.currentIndex,
                          );
                        },
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: palette.surface.withAlpha(232),
                            borderRadius: BorderRadius.circular(34),
                            border: Border.all(color: palette.border),
                            boxShadow: [
                              BoxShadow(
                                color: palette.shadow.withAlpha(70),
                                blurRadius: 36,
                                offset: const Offset(0, 22),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(34),
                            child: navigationShell,
                          ),
                        ),
                      ),
                      const SizedBox(width: 18),
                      SizedBox(
                        width: hasMiniPlayer ? 320 : 280,
                        child: _DesktopSidePanel(
                          snapshot: snapshot,
                          controller: controller,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return Scaffold(
          body: Stack(
            children: [
              Positioned.fill(
                child: AmbientBackground(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: reservedBottomSpace),
                    child: navigationShell,
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      compactBottomChrome ? 10 : 12,
                      0,
                      compactBottomChrome ? 10 : 12,
                      compactBottomChrome ? 10 : 12,
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: palette.navGradient,
                        borderRadius: BorderRadius.circular(
                          compactBottomChrome ? 26 : 30,
                        ),
                        border: Border.all(color: palette.border),
                        boxShadow: [
                          BoxShadow(
                            color: palette.shadow.withAlpha(85),
                            blurRadius: 36,
                            offset: Offset(0, 20),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (hasMiniPlayer) ...[
                            const MiniPlayer(embedded: true),
                            Divider(
                              height: 1,
                              color: palette.border.withAlpha(85),
                            ),
                          ],
                          AppBottomNav(
                            currentIndex: navigationShell.currentIndex,
                            embedded: true,
                            onTap: (index) {
                              navigationShell.goBranch(
                                index,
                                initialLocation:
                                    index == navigationShell.currentIndex,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DesktopSidePanel extends StatelessWidget {
  const _DesktopSidePanel({required this.snapshot, required this.controller});

  final PlaybackSnapshot snapshot;
  final PlaybackController controller;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final track = snapshot.currentTrack;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (track != null) ...[
          GlassPanel(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: palette.accentSoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Now Playing',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: palette.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  track.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  track.artistNames,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => context.push('/player'),
                  icon: const Icon(Icons.open_in_full_rounded),
                  label: const Text('Open Player'),
                ),
                const SizedBox(height: 12),
                const MiniPlayer(embedded: true),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        GlassPanel(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Quick Access',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              Text(
                'Wide web layout keeps navigation fixed, content open, and playback close without eating your scroll space.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: () => context.push('/settings'),
                child: const Text('Settings'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => context.push('/about'),
                child: const Text('About'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
