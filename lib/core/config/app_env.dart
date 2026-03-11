import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppEnv {
  AppEnv({
    required this.musicApiBaseUrl,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.authRedirectScheme,
    required this.authRedirectHost,
  });

  final String musicApiBaseUrl;
  final String? supabaseUrl;
  final String? supabaseAnonKey;
  final String authRedirectScheme;
  final String authRedirectHost;

  bool get hasSupabase =>
      (supabaseUrl?.isNotEmpty ?? false) &&
      (supabaseAnonKey?.isNotEmpty ?? false);

  String get mobileAuthRedirectUrl =>
      '$authRedirectScheme://$authRedirectHost';

  static Future<AppEnv> load() async {
    await dotenv.load(
      fileName: '.env',
      isOptional: true,
      mergeWith: const {
        'JIOSAAVN_BASE_URL': 'https://elitejiosaavn-api.vercel.app',
        'AUTH_REDIRECT_SCHEME': 'aurex',
        'AUTH_REDIRECT_HOST': 'auth-callback',
      },
    );

    return AppEnv(
      musicApiBaseUrl:
          dotenv.env['JIOSAAVN_BASE_URL'] ??
          'https://elitejiosaavn-api.vercel.app',
      supabaseUrl: _clean(dotenv.env['SUPABASE_URL']),
      supabaseAnonKey:
          _clean(dotenv.env['SUPABASE_PUBLISHABLE_KEY']) ??
          _clean(dotenv.env['SUPABASE_ANON_KEY']),
      authRedirectScheme:
          dotenv.env['AUTH_REDIRECT_SCHEME'] ?? 'aurex',
      authRedirectHost:
          dotenv.env['AUTH_REDIRECT_HOST'] ?? 'auth-callback',
    );
  }

  static String? _clean(String? value) {
    if (value == null) {
      return null;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
