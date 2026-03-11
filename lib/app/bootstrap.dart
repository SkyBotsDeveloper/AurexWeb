import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/app_env.dart';
import '../core/config/app_providers.dart';
import '../core/logging/app_logger.dart';
import '../core/storage/app_database.dart';
import 'app.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux) {
    JustAudioMediaKit.ensureInitialized();
  }

  final env = await AppEnv.load();
  final prefs = await SharedPreferences.getInstance();
  final database = await AppDatabase.open();

  if (kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS) {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.skybotsdeveloper.aurex.audio',
      androidNotificationChannelName: 'Aurex Playback',
      androidNotificationOngoing: true,
    );
  }

  SupabaseClient? supabaseClient;
  if (env.hasSupabase) {
    await Supabase.initialize(
      url: env.supabaseUrl!,
      anonKey: env.supabaseAnonKey!,
      debug: kDebugMode,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
    supabaseClient = Supabase.instance.client;
  } else {
    AppLogger.instance.w(
      'Supabase is not configured. Auth, profile sync, and room features are disabled.',
    );
  }

  runApp(
    ProviderScope(
      overrides: [
        appEnvProvider.overrideWithValue(env),
        sharedPreferencesProvider.overrideWithValue(prefs),
        appDatabaseProvider.overrideWithValue(database),
        supabaseClientProvider.overrideWithValue(supabaseClient),
      ],
      child: const AurexApp(),
    ),
  );
}
