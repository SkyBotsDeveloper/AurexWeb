import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_env.dart';
import '../../../core/config/app_providers.dart';
import '../../../core/logging/app_logger.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(appEnvProvider),
  ),
);

final authStateProvider = StreamProvider<AuthSessionState>((ref) {
  return ref.watch(authRepositoryProvider).watchSession();
});

final authEventProvider = StreamProvider<AuthState?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) {
    return Stream<AuthState?>.value(null);
  }
  return ref.watch(authRepositoryProvider).watchAuthEvents();
});

class AuthSessionState {
  const AuthSessionState({required this.isConfigured, required this.session});

  final bool isConfigured;
  final Session? session;

  User? get user => session?.user;
  bool get isSignedIn => session != null;
}

class AuthRepository {
  AuthRepository(this._client, this._env);

  final SupabaseClient? _client;
  final AppEnv _env;

  Session? get currentSession => _client?.auth.currentSession;

  Stream<AuthState?> watchAuthEvents() async* {
    if (_client == null) {
      yield null;
      return;
    }

    while (true) {
      try {
        await for (final data in _client.auth.onAuthStateChange) {
          yield data;
        }
        return;
      } catch (error, stackTrace) {
        _logAuthRecovery('Auth event stream recovered', error, stackTrace);
        await _clearBrokenLocalSessionIfSignedOut();
        yield null;
        await Future<void>.delayed(const Duration(milliseconds: 600));
      }
    }
  }

  Stream<AuthSessionState> watchSession() async* {
    if (_client == null) {
      yield const AuthSessionState(isConfigured: false, session: null);
      return;
    }

    yield AuthSessionState(
      isConfigured: true,
      session: _client.auth.currentSession,
    );

    while (true) {
      try {
        await for (final data in _client.auth.onAuthStateChange) {
          yield AuthSessionState(
            isConfigured: true,
            session: data.session ?? _client.auth.currentSession,
          );
        }
        return;
      } catch (error, stackTrace) {
        _logAuthRecovery('Auth session stream recovered', error, stackTrace);
        await _clearBrokenLocalSessionIfSignedOut();
        yield AuthSessionState(
          isConfigured: true,
          session: _client.auth.currentSession,
        );
        await Future<void>.delayed(const Duration(milliseconds: 600));
      }
    }
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    _requireClient();
    await _client!.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    _requireClient();
    await _client!.auth.signUp(email: email, password: password);
  }

  Future<void> sendPasswordReset(String email) async {
    _requireClient();
    await _client!.auth.resetPasswordForEmail(
      email,
      redirectTo: _passwordResetRedirectUrl(),
    );
  }

  Future<void> signInWithGoogle() async {
    _requireClient();
    await _client!.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: _googleRedirectUrl(),
    );
  }

  Future<void> updatePassword(String password) async {
    _requireClient();
    await _client!.auth.updateUser(UserAttributes(password: password));
  }

  Future<void> signOut() async {
    _requireClient();
    await _client!.auth.signOut();
  }

  Future<void> _clearBrokenLocalSessionIfSignedOut() async {
    final client = _client;
    if (client == null || client.auth.currentSession != null) {
      return;
    }

    try {
      await client.auth.signOut();
    } catch (error, stackTrace) {
      _logAuthRecovery(
        'Unable to clear broken local auth session',
        error,
        stackTrace,
      );
    }
  }

  void _logAuthRecovery(String message, Object error, StackTrace stackTrace) {
    if (kDebugMode) {
      AppLogger.instance.w(message, error: error, stackTrace: stackTrace);
    }
  }

  void _requireClient() {
    if (_client == null) {
      throw const AuthException('Sign in is not available right now.');
    }
  }

  String? _googleRedirectUrl() {
    if (!kIsWeb) {
      return _env.mobileAuthRedirectUrl;
    }
    return '${Uri.base.origin}/home';
  }

  String? _passwordResetRedirectUrl() {
    if (!kIsWeb) {
      return _env.mobileAuthRedirectUrl;
    }
    return '${Uri.base.origin}/auth/recovery';
  }
}
