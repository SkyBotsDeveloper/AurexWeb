import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_providers.dart';
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
    required this.streamingQuality,
    required this.downloadQuality,
    required this.autoQuality,
    required this.rememberQueue,
    required this.autoResyncRooms,
  });

  final AppThemePreference themePreference;
  final AudioQuality streamingQuality;
  final AudioQuality downloadQuality;
  final bool autoQuality;
  final bool rememberQueue;
  final bool autoResyncRooms;

  AppSettings copyWith({
    AppThemePreference? themePreference,
    AudioQuality? streamingQuality,
    AudioQuality? downloadQuality,
    bool? autoQuality,
    bool? rememberQueue,
    bool? autoResyncRooms,
  }) {
    return AppSettings(
      themePreference: themePreference ?? this.themePreference,
      streamingQuality: streamingQuality ?? this.streamingQuality,
      downloadQuality: downloadQuality ?? this.downloadQuality,
      autoQuality: autoQuality ?? this.autoQuality,
      rememberQueue: rememberQueue ?? this.rememberQueue,
      autoResyncRooms: autoResyncRooms ?? this.autoResyncRooms,
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
          streamingQuality: AudioQuality.fromKey(
            _prefs.getString(_streamingQualityKey),
          ),
          downloadQuality: AudioQuality.fromKey(
            _prefs.getString(_downloadQualityKey),
          ),
          autoQuality: _prefs.getBool(_autoQualityKey) ?? true,
          rememberQueue: _prefs.getBool(_rememberQueueKey) ?? true,
          autoResyncRooms: _prefs.getBool(_autoResyncRoomsKey) ?? true,
        ),
      );

  final SharedPreferences _prefs;
  final ValueNotifier<AppSettings> notifier;

  static const _themePreferenceKey = 'settings.theme_preference';
  static const _streamingQualityKey = 'settings.streaming_quality';
  static const _downloadQualityKey = 'settings.download_quality';
  static const _autoQualityKey = 'settings.auto_quality';
  static const _rememberQueueKey = 'settings.remember_queue';
  static const _autoResyncRoomsKey = 'settings.auto_resync_rooms';

  AppSettings get current => notifier.value;

  Future<void> updateThemePreference(AppThemePreference preference) async {
    await _prefs.setString(_themePreferenceKey, preference.name);
    notifier.value = notifier.value.copyWith(themePreference: preference);
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
}
