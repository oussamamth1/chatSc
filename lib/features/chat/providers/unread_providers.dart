import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_providers.dart';
import 'profile_providers.dart';

/// Unread message counts per conversation partner, keyed by username.
/// Refreshed on login and whenever a chat screen is closed (opening it
/// marks its messages read server-side).
final unreadCountsProvider = FutureProvider<Map<String, int>>((ref) async {
  final auth = ref.watch(authControllerProvider);
  if (auth.token == null) return {};
  return ref.watch(profileServiceProvider).getUnreadCounts(auth.token!);
});
