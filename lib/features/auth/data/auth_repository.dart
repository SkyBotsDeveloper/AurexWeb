import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_env.dart';
import '../../../core/config/app_providers.dart';

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
  return client.auth.onAuthStateChange;
});

class AuthSessionState {
  const AuthSessionState({
    required this.isConfigured,
    required this.session,
  });

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

  Stream<AuthSessionState> watchSession() async* {
    if (_client == null) {
      yield const AuthSessionState(isConfigured: false, session: null);
      return;
    }

    yield AuthSessionState(
      isConfigured: true,
      session: _client.auth.currentSession,
    );

    yield* _client.auth.onAuthStateChange.map(
      (data) => AuthSessionState(isConfigured: true, session: data.session),
    );
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

  void _requireClient() {
    if (_client == null) {
      throw const AuthException(
        'Sign in is not available right now.',
      );
    }
  }

  String? _googleRedirectUrl() {
    if (!kIsWeb) {
      return _env.mobileAuthRedirectUrl;
    }
    return '${Uri.base.origin}/#/home';
  }

  String? _passwordResetRedirectUrl() {
    if (!kIsWeb) {
      return _env.mobileAuthRedirectUrl;
    }
    return '${Uri.base.origin}/#/auth/recovery';
  }
}
