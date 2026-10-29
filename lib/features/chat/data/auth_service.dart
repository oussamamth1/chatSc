import 'package:dio/dio.dart';

class AuthService {
  AuthService(this._dio);

  final Dio _dio;

  Future<String> register(String username, String password) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/register',
      data: {'username': username, 'password': password},
    );
    return response.data!['token'] as String;
  }

  Future<String> login(String username, String password) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'username': username, 'password': password},
    );
    return response.data!['token'] as String;
  }

  /// Confirms a stored token is still valid against the current backend —
  /// a token saved while testing against one server (e.g. local) won't
  /// exist on another (e.g. production), so a cached session must be
  /// re-verified rather than trusted blindly.
  Future<bool> verify(String token) async {
    try {
      await _dio.get('/me', options: Options(headers: {'Authorization': 'Bearer $token'}));
      return true;
    } on DioException {
      return false;
    }
  }
}
