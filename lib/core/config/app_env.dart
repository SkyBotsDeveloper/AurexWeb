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
      musicApiBaseUrl: _clean(_musicApiBaseUrl) ?? _defaultMusicApiBaseUrl,
      aurexApiBaseUrl: _clean(_aurexApiBaseUrl) ?? _defaultAurexApiBaseUrl,
      supabaseUrl: _clean(_supabaseUrl),
      supabaseAnonKey:
          _clean(_supabasePublishableKey) ?? _clean(_supabaseAnonKey),
      authRedirectScheme: _clean(_authRedirectScheme) ?? 'aurex',
      authRedirectHost: _clean(_authRedirectHost) ?? 'auth-callback',
    );
  }

  static const _defaultMusicApiBaseUrl = 'https://elitejiosaavn-api.vercel.app';
  static const _defaultAurexApiBaseUrl = 'https://aurex-api-two.vercel.app';
  static const _musicApiBaseUrl = String.fromEnvironment(
    'JIOSAAVN_BASE_URL',
    defaultValue: _defaultMusicApiBaseUrl,
  );
  static const _aurexApiBaseUrl = String.fromEnvironment(
    'AUREX_API_BASE_URL',
    defaultValue: _defaultAurexApiBaseUrl,
  );
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
}
