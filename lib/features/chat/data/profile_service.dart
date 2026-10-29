import 'package:dio/dio.dart';

import 'user_profile.dart';

class ProfileService {
  ProfileService(this._dio);

  final Dio _dio;

  Options _auth(String token) => Options(headers: {'Authorization': 'Bearer $token'});

  Future<UserProfile> getMe(String token) async {
    final response = await _dio.get<Map<String, dynamic>>('/me', options: _auth(token));
    return UserProfile.fromJson(response.data!);
  }

  Future<UserProfile> updateStatus(String status, String token) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/me',
      data: {'status': status},
      options: _auth(token),
    );
    return UserProfile.fromJson(response.data!);
  }

  Future<UserProfile> getUser(String username, String token) async {
    final response = await _dio.get<Map<String, dynamic>>('/users/$username', options: _auth(token));
    return UserProfile.fromJson(response.data!);
  }

  Future<Map<String, int>> getUnreadCounts(String token) async {
    final response = await _dio.get<List<dynamic>>('/chat/unread-counts', options: _auth(token));
    return {
      for (final row in response.data!)
        (row as Map<String, dynamic>)['otherUsername'] as String: row['count'] as int,
    };
  }
}
