import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../download/providers/download_providers.dart';
import '../data/friend_profile.dart';
import '../data/friend_request.dart';
import '../data/friends_service.dart';
import 'auth_providers.dart';

final friendsServiceProvider = Provider<FriendsService>((ref) {
  return FriendsService(ref.watch(dioProvider));
});

enum FriendsStatus { idle, loading, error }

class FriendsState {
  final FriendsStatus status;
  final List<FriendProfile> friends;
  final List<FriendRequest> incoming;
  final List<FriendProfile> searchResults;
  final String? errorMessage;

  const FriendsState({
    this.status = FriendsStatus.idle,
    this.friends = const [],
    this.incoming = const [],
    this.searchResults = const [],
    this.errorMessage,
  });

  FriendsState copyWith({
    FriendsStatus? status,
    List<FriendProfile>? friends,
    List<FriendRequest>? incoming,
    List<FriendProfile>? searchResults,
    String? errorMessage,
  }) {
    return FriendsState(
      status: status ?? this.status,
      friends: friends ?? this.friends,
      incoming: incoming ?? this.incoming,
      searchResults: searchResults ?? this.searchResults,
      errorMessage: errorMessage,
    );
  }
}

class FriendsController extends StateNotifier<FriendsState> {
  FriendsController(this._service, this._tokenProvider) : super(const FriendsState()) {
    refresh();
  }

  final FriendsService _service;
  final String Function() _tokenProvider;

  Future<void> refresh() async {
    state = state.copyWith(status: FriendsStatus.loading, errorMessage: null);
    try {
      final token = _tokenProvider();
      final friends = await _service.friends(token);
      final incoming = await _service.incomingRequests(token);
      state = state.copyWith(
        status: FriendsStatus.idle,
        friends: friends,
        incoming: incoming,
      );
    } catch (e) {
      state = state.copyWith(status: FriendsStatus.error, errorMessage: _message(e));
    }
  }

  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      state = state.copyWith(searchResults: []);
      return;
    }
    try {
      final results = await _service.search(query.trim(), _tokenProvider());
      state = state.copyWith(searchResults: results);
    } catch (_) {
      // Leave previous results; search errors aren't critical enough to surface.
    }
  }

  Future<String?> sendRequest(String username) async {
    try {
      await _service.sendRequest(username, _tokenProvider());
      return null;
    } catch (e) {
      return _message(e);
    }
  }

  Future<void> accept(String id) async {
    await _service.accept(id, _tokenProvider());
    await refresh();
  }

  Future<void> decline(String id) async {
    await _service.decline(id, _tokenProvider());
    await refresh();
  }

  String _message(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['message'] != null) {
        final message = data['message'];
        return message is List ? message.join(', ') : message.toString();
      }
      return e.message ?? 'Something went wrong';
    }
    return e.toString();
  }
}

final friendsControllerProvider = StateNotifierProvider.autoDispose<FriendsController, FriendsState>((ref) {
  // A snapshot, not a live subscription — see profile_providers.dart for why.
  final auth = ref.read(authControllerProvider);
  return FriendsController(ref.watch(friendsServiceProvider), () => auth.token!);
});
