import 'package:shared_preferences/shared_preferences.dart';

/// Persists the list of people a user has started conversations with.
/// Scoped per-account so switching logins doesn't mix up chat lists.
/// Never stores the shared code — only who the conversation is with.
class ConversationStore {
  Future<List<String>> load(String me) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key(me)) ?? [];
  }

  Future<void> save(String me, List<String> conversations) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key(me), conversations);
  }

  String _key(String me) => 'conversations_${me.toLowerCase()}';
}
