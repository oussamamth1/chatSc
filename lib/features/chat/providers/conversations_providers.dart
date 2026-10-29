import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/conversation_store.dart';
import 'auth_providers.dart';

final conversationStoreProvider = Provider<ConversationStore>((ref) => ConversationStore());

class ConversationsController extends StateNotifier<List<String>> {
  ConversationsController(this._store, this._me) : super([]) {
    _load();
  }

  final ConversationStore _store;
  final String _me;

  Future<void> _load() async {
    state = await _store.load(_me);
  }

  Future<void> addConversation(String otherUsername) async {
    final normalized = otherUsername.trim();
    if (state.any((u) => u.toLowerCase() == normalized.toLowerCase())) return;
    final updated = [...state, normalized];
    state = updated;
    await _store.save(_me, updated);
  }

  Future<void> removeConversation(String otherUsername) async {
    final updated = state.where((u) => u.toLowerCase() != otherUsername.toLowerCase()).toList();
    if (updated.length == state.length) return;
    state = updated;
    await _store.save(_me, updated);
  }
}

final conversationsControllerProvider =
    StateNotifierProvider.autoDispose<ConversationsController, List<String>>((ref) {
  // A snapshot, not a live subscription — see profile_providers.dart for why.
  final me = ref.read(authControllerProvider).username!;
  return ConversationsController(ref.watch(conversationStoreProvider), me);
});

/// In-memory only: consecutive times a wrong shared code was entered for a
/// conversation (all existing messages failed to decrypt), keyed by
/// lowercase username. Reset to 0 on a correct code.
final wrongCodeAttemptsProvider = StateProvider<Map<String, int>>((ref) => {});
