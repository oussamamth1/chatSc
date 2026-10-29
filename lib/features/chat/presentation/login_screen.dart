import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../providers/auth_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isRegistering = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final isLoading = auth.status == AuthStatus.loading;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Terminal-style wordmark instead of a centered logo mark —
                  // this is the one place the mono "readout" voice gets room.
                  Text('> secure_channel', style: mono(context, size: 13, color: AppColors.moss)),
                  const SizedBox(height: 10),
                  Text(
                    'CIPHER',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Messages are encrypted on your device with a code only\nyou and the other person know. We never see it.',
                    style: TextStyle(color: AppColors.mist, height: 1.5),
                  ),
                  const SizedBox(height: 32),
                  DispatchPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isRegistering ? 'Create your account' : 'Welcome back',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _usernameController,
                          decoration: const InputDecoration(labelText: 'Username'),
                          autocorrect: false,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                color: AppColors.mist,
                              ),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _submit(),
                        ),
                        const SizedBox(height: 20),
                        if (auth.status == AuthStatus.error)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Text(
                              auth.errorMessage ?? 'Something went wrong',
                              style: const TextStyle(color: AppColors.danger, fontSize: 13),
                            ),
                          ),
                        FilledButton(
                          onPressed: isLoading ? null : _submit,
                          child: isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onSignal),
                                )
                              : Text(_isRegistering ? 'Create account' : 'Log in'),
                        ),
                        const SizedBox(height: 4),
                        Center(
                          child: TextButton(
                            onPressed: isLoading
                                ? null
                                : () => setState(() => _isRegistering = !_isRegistering),
                            child: Text(
                              _isRegistering
                                  ? 'Already have an account? Log in'
                                  : "Don't have an account? Register",
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _submit() {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    if (username.isEmpty || password.isEmpty) return;
    if (_isRegistering) {
      ref.read(authControllerProvider.notifier).register(username, password);
    } else {
      ref.read(authControllerProvider.notifier).login(username, password);
    }
  }
}
