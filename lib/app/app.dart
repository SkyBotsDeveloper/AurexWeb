import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/theme/app_scroll_behavior.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/rooms/data/room_sync_service.dart';
import '../features/settings/data/settings_repository.dart';
import 'router/app_router.dart';

class AurexApp extends ConsumerWidget {
  const AurexApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final settingsRepository = ref.watch(settingsRepositoryProvider);
    ref.watch(roomSyncServiceProvider);

    ref.listen<AsyncValue<AuthState?>>(authEventProvider, (_, next) {
      final authState = next.asData?.value;
      if (authState?.event == AuthChangeEvent.passwordRecovery) {
        router.go('/auth/recovery');
      }
    });

    return ValueListenableBuilder(
      valueListenable: settingsRepository.notifier,
      builder: (context, settings, child) {
        return MaterialApp.router(
          title: 'Aurex',
          debugShowCheckedModeBanner: false,
          scrollBehavior: const AurexScrollBehavior(),
          themeMode: settings.themePreference.themeMode,
          theme: AppTheme.lightTheme(settings.themeColorPreference),
          darkTheme: AppTheme.darkTheme(settings.themeColorPreference),
          routerConfig: router,
        );
      },
    );
  }
}
