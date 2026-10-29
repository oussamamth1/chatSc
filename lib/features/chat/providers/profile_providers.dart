import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../download/providers/download_providers.dart';
import '../data/profile_service.dart';
import '../data/user_profile.dart';
import 'auth_providers.dart';

final profileServiceProvider = Provider<ProfileService>((ref) {
  return ProfileService(ref.watch(dioProvider));
});

class ProfileController extends StateNotifier<UserProfile?> {
  ProfileController(this._service, this._tokenProvider, this._username) : super(null) {
    refresh();
  }

  final ProfileService _service;
  final String Function() _tokenProvider;
  final String _username;

  Future<void> refresh() async {
    try {
      state = await _service.getMe(_tokenProvider());
    } catch (_) {
      state = UserProfile(username: _username, status: '');
    }
  }

  Future<bool> updateStatus(String status) async {
    try {
      state = await _service.updateStatus(status, _tokenProvider());
      return true;
    } catch (_) {
      return false;
    }
  }
}

final profileControllerProvider = StateNotifierProvider.autoDispose<ProfileController, UserProfile?>((ref) {
  // A snapshot, not a live subscription: this controller shouldn't be torn
  // down and recreated (crashing on the null `!`) if auth state changes
  // later, e.g. on logout, while this provider is still briefly alive.
  final auth = ref.read(authControllerProvider);
  return ProfileController(ref.watch(profileServiceProvider), () => auth.token!, auth.username!);
});

/// One-shot fetch of another user's public status/online snapshot — not
/// live-updating, just refreshed each time a chat with them is opened.
final otherUserProfileProvider =
    FutureProvider.autoDispose.family<UserProfile, String>((ref, username) async {
  final auth = ref.read(authControllerProvider);
  return ref.watch(profileServiceProvider).getUser(username, auth.token!);
});
