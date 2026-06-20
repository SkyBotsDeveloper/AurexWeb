import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../music/domain/music_models.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(sharedPreferencesProvider)),
);

enum AppThemePreference {
  dark,
  light;

  static AppThemePreference fromKey(String? key) {
    return values.firstWhere(
      (mode) => mode.name == key,
      orElse: () => AppThemePreference.dark,
    );
  }

  ThemeMode get themeMode =>
      this == AppThemePreference.light ? ThemeMode.light : ThemeMode.dark;

  String get label => this == AppThemePreference.light ? 'Light' : 'Dark';
}

class AppSettings {
  const AppSettings({
    required this.themePreference,
    required this.themeColorPreference,
    required this.streamingQuality,
    required this.downloadQuality,
    required this.autoQuality,
    required this.rememberQueue,
    required this.autoResyncRooms,
    required this.smartCacheEnabled,
  });

  final AppThemePreference themePreference;
  final AppThemeColorPreference themeColorPreference;
  final AudioQuality streamingQuality;
  final AudioQuality downloadQuality;
  final bool autoQuality;
  final bool rememberQueue;
  final bool autoResyncRooms;
  final bool smartCacheEnabled;

  AppSettings copyWith({
    AppThemePreference? themePreference,
    AppThemeColorPreference? themeColorPreference,
    AudioQuality? streamingQuality,
    AudioQuality? downloadQuality,
    bool? autoQuality,
    bool? rememberQueue,
    bool? autoResyncRooms,
    bool? smartCacheEnabled,
  }) {
    return AppSettings(
      themePreference: themePreference ?? this.themePreference,
      themeColorPreference: themeColorPreference ?? this.themeColorPreference,
      streamingQuality: streamingQuality ?? this.streamingQuality,
      downloadQuality: downloadQuality ?? this.downloadQuality,
      autoQuality: autoQuality ?? this.autoQuality,
      rememberQueue: rememberQueue ?? this.rememberQueue,
      autoResyncRooms: autoResyncRooms ?? this.autoResyncRooms,
      smartCacheEnabled: smartCacheEnabled ?? this.smartCacheEnabled,
    );
  }
}

class SettingsRepository {
  SettingsRepository(this._prefs)
    : notifier = ValueNotifier<AppSettings>(
        AppSettings(
          themePreference: AppThemePreference.fromKey(
            _prefs.getString(_themePreferenceKey),
          ),
          themeColorPreference: AppThemeColorPreference.fromKey(
            _prefs.getString(_themeColorPreferenceKey) ??
                _prefs.getString(_legacyLogoColorPreferenceKey),
          ),
          streamingQuality: AudioQuality.fromKey(
            _prefs.getString(_streamingQualityKey),
          ),
          downloadQuality: AudioQuality.fromKey(
            _prefs.getString(_downloadQualityKey),
          ),
          autoQuality: _prefs.getBool(_autoQualityKey) ?? true,
          rememberQueue: _prefs.getBool(_rememberQueueKey) ?? true,
          autoResyncRooms: _prefs.getBool(_autoResyncRoomsKey) ?? true,
          smartCacheEnabled: _prefs.getBool(_smartCacheEnabledKey) ?? true,
        ),
      );

  final SharedPreferences _prefs;
  final ValueNotifier<AppSettings> notifier;

  static const _themePreferenceKey = 'settings.theme_preference';
  static const _themeColorPreferenceKey = 'settings.theme_color_preference';
  static const _legacyLogoColorPreferenceKey = 'settings.logo_color_preference';
  static const _streamingQualityKey = 'settings.streaming_quality';
  static const _downloadQualityKey = 'settings.download_quality';
  static const _autoQualityKey = 'settings.auto_quality';
  static const _rememberQueueKey = 'settings.remember_queue';
  static const _autoResyncRoomsKey = 'settings.auto_resync_rooms';
  static const _smartCacheEnabledKey = 'settings.smart_cache_enabled';

  AppSettings get current => notifier.value;

  Future<void> updateThemePreference(AppThemePreference preference) async {
    await _prefs.setString(_themePreferenceKey, preference.name);
    notifier.value = notifier.value.copyWith(themePreference: preference);
  }

  Future<void> updateThemeColorPreference(
    AppThemeColorPreference preference,
  ) async {
    await _prefs.setString(_themeColorPreferenceKey, preference.name);
    await _prefs.remove(_legacyLogoColorPreferenceKey);
    notifier.value = notifier.value.copyWith(themeColorPreference: preference);
  }

  Future<void> updateStreamingQuality(AudioQuality quality) async {
    await _prefs.setString(_streamingQualityKey, quality.key);
    notifier.value = notifier.value.copyWith(streamingQuality: quality);
  }

  Future<void> updateDownloadQuality(AudioQuality quality) async {
    await _prefs.setString(_downloadQualityKey, quality.key);
    notifier.value = notifier.value.copyWith(downloadQuality: quality);
  }

  Future<void> setAutoQuality(bool value) async {
    await _prefs.setBool(_autoQualityKey, value);
    notifier.value = notifier.value.copyWith(autoQuality: value);
  }

  Future<void> setRememberQueue(bool value) async {
    await _prefs.setBool(_rememberQueueKey, value);
    notifier.value = notifier.value.copyWith(rememberQueue: value);
  }

  Future<void> setAutoResyncRooms(bool value) async {
    await _prefs.setBool(_autoResyncRoomsKey, value);
    notifier.value = notifier.value.copyWith(autoResyncRooms: value);
  }

  Future<void> setSmartCacheEnabled(bool value) async {
    await _prefs.setBool(_smartCacheEnabledKey, value);
    notifier.value = notifier.value.copyWith(smartCacheEnabled: value);
  }
}
