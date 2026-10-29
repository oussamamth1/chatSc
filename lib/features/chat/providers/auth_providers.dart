import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../download/providers/download_providers.dart';
import '../data/auth_service.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(dioProvider));
});

enum AuthStatus { unknown, loggedOut, loading, loggedIn, error }

class AuthState {
  final AuthStatus status;
  final String? username;
  final String? token;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.username,
    this.token,
    this.errorMessage,
  });

  AuthState copyWith({
    AuthStatus? status,
    String? username,
    String? token,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      username: username ?? this.username,
      token: token ?? this.token,
      errorMessage: errorMessage,
    );
  }
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._service) : super(const AuthState()) {
    _restore();
  }

  final AuthService _service;
  static const _tokenKey = 'chat_token';
  static const _usernameKey = 'chat_username';

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    final username = prefs.getString(_usernameKey);
    if (token != null && username != null && await _service.verify(token)) {
      state = AuthState(status: AuthStatus.loggedIn, token: token, username: username);
    } else {
      // Stale session (e.g. saved while pointed at a different backend) —
      // don't trust it; clear it so the UI doesn't look "logged in" while
      // every API call then fails with 401.
      await prefs.remove(_tokenKey);
      await prefs.remove(_usernameKey);
      state = const AuthState(status: AuthStatus.loggedOut);
    }
  }

  Future<void> register(String username, String password) =>
      _authenticate(username, () => _service.register(username, password));

  Future<void> login(String username, String password) =>
      _authenticate(username, () => _service.login(username, password));

  Future<void> _authenticate(String username, Future<String> Function() action) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      final token = await action();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
      await prefs.setString(_usernameKey, username);
      state = AuthState(status: AuthStatus.loggedIn, token: token, username: username);
    } on DioException catch (e) {
      state = state.copyWith(status: AuthStatus.error, errorMessage: _extractError(e));
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_usernameKey);
    state = const AuthState(status: AuthStatus.loggedOut);
  }

  String _extractError(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      final message = data['message'];
      return message is List ? message.join(', ') : message.toString();
    }
    return e.message ?? 'Something went wrong';
  }
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref.watch(authServiceProvider));
});
