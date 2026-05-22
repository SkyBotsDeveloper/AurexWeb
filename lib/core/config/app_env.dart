import 'package:flutter/foundation.dart';

class AppEnv {
  AppEnv({
    required this.musicApiBaseUrl,
    required this.aurexApiBaseUrl,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.authRedirectScheme,
    required this.authRedirectHost,
  });

  final String musicApiBaseUrl;
  final String aurexApiBaseUrl;
  final String? supabaseUrl;
  final String? supabaseAnonKey;
  final String authRedirectScheme;
  final String authRedirectHost;

  bool get hasSupabase =>
      (supabaseUrl?.isNotEmpty ?? false) &&
      (supabaseAnonKey?.isNotEmpty ?? false);

  String get mobileAuthRedirectUrl => '$authRedirectScheme://$authRedirectHost';

  static Future<AppEnv> load() async {
    return AppEnv(
      musicApiBaseUrl:
          _cleanApiBaseUrl(_musicApiBaseUrl) ?? _defaultMusicApiBaseUrl,
      aurexApiBaseUrl:
          _cleanApiBaseUrl(_aurexApiBaseUrl) ?? _defaultAurexApiBaseUrl,
      supabaseUrl: _clean(_supabaseUrl) ?? _defaultSupabaseUrl,
      supabaseAnonKey:
          _clean(_supabasePublishableKey) ??
          _clean(_supabaseAnonKey) ??
          _defaultSupabasePublishableKey,
      authRedirectScheme: _clean(_authRedirectScheme) ?? 'aurex',
      authRedirectHost: _clean(_authRedirectHost) ?? 'auth-callback',
    );
  }

  static String get _defaultMusicApiBaseUrl =>
      kIsWeb ? '/music-api' : 'https://elitejiosaavn-api.vercel.app';
  static String get _defaultAurexApiBaseUrl =>
      kIsWeb ? '/aurex-api' : 'https://aurex-api-two.vercel.app';
  static const _defaultSupabaseUrl = 'https://xbwxwhimlghtppmpyqhi.supabase.co';
  static const _defaultSupabasePublishableKey =
      'sb_publishable_GUG5zMWizrNP959CCRY3mg_73j1Cf-7';
  static const _musicApiBaseUrl = String.fromEnvironment('JIOSAAVN_BASE_URL');
  static const _aurexApiBaseUrl = String.fromEnvironment('AUREX_API_BASE_URL');
  static const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const _supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );
  static const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const _authRedirectScheme = String.fromEnvironment(
    'AUTH_REDIRECT_SCHEME',
    defaultValue: 'aurex',
  );
  static const _authRedirectHost = String.fromEnvironment(
    'AUTH_REDIRECT_HOST',
    defaultValue: 'auth-callback',
  );

  static String? _clean(String? value) {
    if (value == null) {
      return null;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static String? _cleanApiBaseUrl(String? value) {
    final cleaned = _clean(value);
    if (cleaned == null) {
      return null;
    }
    if (!kIsWeb && cleaned.startsWith('/')) {
      return null;
    }
    return cleaned;
  }
}
