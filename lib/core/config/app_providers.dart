import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../logging/app_logger.dart';
import '../storage/app_database.dart';
import 'app_env.dart';

final appEnvProvider = Provider<AppEnv>(
  (ref) => throw UnimplementedError('AppEnv was not initialized.'),
);

final appDatabaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('AppDatabase was not initialized.'),
);

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('SharedPreferences was not initialized.'),
);

final appLoggerProvider = Provider<Logger>((ref) => AppLogger.instance);

final supabaseClientProvider = Provider<SupabaseClient?>((ref) => null);
