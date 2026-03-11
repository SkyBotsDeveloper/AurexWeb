import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/glass_panel.dart';
import '../../../core/widgets/state_scaffold.dart';
import '../data/auth_repository.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  bool _isSignUp = false;
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _run(
    Future<void> Function(AuthRepository repo) action, {
    String? successMessage,
  }) async {
    setState(() => _loading = true);
    try {
      await action(ref.read(authRepositoryProvider));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              successMessage ??
                  (_isSignUp
                      ? 'Account created. Check your inbox if email confirmation is enabled.'
                      : 'Signed in successfully.'),
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String get _email => _emailController.text.trim();

  bool _hasValidEmail() => _emailPattern.hasMatch(_email);

  Future<void> _submitEmailAuth() async {
    if (!_hasValidEmail()) {
      _showMessage('Enter a valid email address first.');
      return;
    }

    if (_passwordController.text.isEmpty) {
      _showMessage('Enter your password first.');
      return;
    }

    await _run(
      (repo) {
        if (_isSignUp) {
          return repo.signUpWithEmail(
            email: _email,
            password: _passwordController.text,
          );
        }
        return repo.signInWithEmail(
          email: _email,
          password: _passwordController.text,
        );
      },
    );
  }

  Future<void> _sendPasswordReset() async {
    if (!_hasValidEmail()) {
      _showMessage('Enter the account email first, then try again.');
      return;
    }

    await _run(
      (repo) => repo.sendPasswordReset(_email),
      successMessage: 'Password reset link sent. Check your inbox.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final session = authState.asData?.value;

    if (session?.isConfigured == false) {
      return const Scaffold(
        body: StateScaffold(
          icon: Icons.lock_outline_rounded,
          title: 'Sign in unavailable',
          message:
              'Sign in is not available right now. Finish account setup to enable email and Google login.',
        ),
      );
    }

    if (session?.isSignedIn == true) {
      return Scaffold(
        body: StateScaffold(
          icon: Icons.verified_user_outlined,
          title: 'You are already signed in',
          message:
              'Your account is active. Open your profile to manage settings and sign-out.',
          action: FilledButton(
            onPressed: () => context.go('/profile'),
            child: const Text('Open Profile'),
          ),
        ),
      );
    }

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 36, 20, 24),
        children: [
          Text('Welcome to Aurex', style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 8),
          Text(
            'Sign in with email or continue with Google to sync your profile and library.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          GlassPanel(
            child: Column(
              children: [
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Sign In')),
                    ButtonSegment(value: true, label: Text('Sign Up')),
                  ],
                  selected: {_isSignUp},
                  onSelectionChanged: (value) {
                    setState(() => _isSignUp = value.first);
                  },
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock_outline_rounded),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _loading ? null : _submitEmailAuth,
                  child: Text(_isSignUp ? 'Create Account' : 'Sign In'),
                ),
                TextButton(
                  onPressed: _loading ? null : _sendPasswordReset,
                  child: const Text('Forgot password?'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _loading
                      ? null
                      : () => _run(
                            (repo) => repo.signInWithGoogle(),
                            successMessage:
                                'Continue in the browser to finish Google sign-in.',
                          ),
                  icon: const Icon(Icons.account_circle_rounded),
                  label: const Text('Continue with Google'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
