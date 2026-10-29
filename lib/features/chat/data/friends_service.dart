import 'package:dio/dio.dart';

import 'friend_profile.dart';
import 'friend_request.dart';

class FriendsService {
  FriendsService(this._dio);

  final Dio _dio;

  Options _auth(String token) => Options(headers: {'Authorization': 'Bearer $token'});

  Future<List<FriendProfile>> search(String query, String token) async {
    final response = await _dio.get<List<dynamic>>(
      '/friends/search',
      queryParameters: {'q': query},
      options: _auth(token),
    );
    return (response.data ?? [])
        .map((raw) => FriendProfile.fromJson(raw as Map<String, dynamic>))
        .toList();
  }

  Future<void> sendRequest(String username, String token) async {
    await _dio.post('/friends/requests', data: {'username': username}, options: _auth(token));
  }

  Future<List<FriendRequest>> incomingRequests(String token) async {
    final response = await _dio.get<List<dynamic>>('/friends/requests/incoming', options: _auth(token));
    return (response.data ?? [])
        .map((raw) => FriendRequest.fromJson(raw as Map<String, dynamic>))
        .toList();
  }

  Future<void> accept(String id, String token) async {
    await _dio.post('/friends/requests/$id/accept', options: _auth(token));
  }

  Future<void> decline(String id, String token) async {
    await _dio.post('/friends/requests/$id/decline', options: _auth(token));
  }

  Future<List<FriendProfile>> friends(String token) async {
    final response = await _dio.get<List<dynamic>>('/friends', options: _auth(token));
    return (response.data ?? [])
        .map((raw) => FriendProfile.fromJson(raw as Map<String, dynamic>))
        .toList();
  }
}
