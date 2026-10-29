import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../providers/auth_providers.dart';
import '../providers/conversations_providers.dart';
import '../providers/profile_providers.dart';
import '../providers/unread_providers.dart';
import 'chat_screen.dart';
import 'chat_setup_screen.dart';
import 'friends_screen.dart';

class ConversationsScreen extends ConsumerWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final profile = ref.watch(profileControllerProvider);
    final conversations = ref.watch(conversationsControllerProvider);
    final unreadCounts = ref.watch(unreadCountsProvider).value ?? const {};

    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: () => _editStatus(context, ref, profile?.status ?? ''),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InitialTile(label: auth.username ?? '?', size: 38),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(auth.username ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      profile == null || profile.status.isEmpty ? 'Tap to set a status' : profile.status,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5, color: AppColors.mist),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Friends',
            icon: const Icon(Icons.group_outlined),
            onPressed: () => _openFriends(context, ref),
          ),
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: conversations.isEmpty
          ? _EmptyConversations(onStart: () => _startNewConversation(context))
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: conversations.length,
              separatorBuilder: (_, _) => const Divider(height: 1, indent: 20),
              itemBuilder: (context, index) {
                final otherUsername = conversations[index];
                final unread = unreadCounts[otherUsername] ?? 0;
                return InkWell(
                  onTap: () => _openConversation(context, ref, otherUsername),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    child: Row(
                      children: [
                        // A thin signal-colored rail marks a conversation
                        // that's set up and ready, instead of a trailing chevron.
                        Container(width: 3, height: 32, color: AppColors.signal),
                        const SizedBox(width: 14),
                        InitialTile(label: otherUsername, size: 40),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(otherUsername, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15.5)),
                              const SizedBox(height: 6),
                              // Shown, not told: a redacted strip stands in
                              // for "you need the code to read this".
                              const RedactionBar(width: 96, height: 9),
                            ],
                          ),
                        ),
                        if (unread > 0) ...[
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.signal,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              unread > 99 ? '99+' : '$unread',
                              style: const TextStyle(
                                color: AppColors.onSignal,
                                fontWeight: FontWeight.w700,
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _startNewConversation(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New chat'),
      ),
    );
  }

  Future<void> _editStatus(BuildContext context, WidgetRef ref, String currentStatus) async {
    final controller = TextEditingController(text: currentStatus);
    final newStatus = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Your status'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 140,
          maxLines: 2,
          decoration: const InputDecoration(hintText: "What's on your mind?"),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(controller.text), child: const Text('Save')),
        ],
      ),
    );
    if (newStatus == null || newStatus.trim() == currentStatus) return;
    final ok = await ref.read(profileControllerProvider.notifier).updateStatus(newStatus.trim());
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not update status')));
    }
  }

  Future<void> _startNewConversation(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ChatSetupScreen()),
    );
  }

  Future<void> _openFriends(BuildContext context, WidgetRef ref) async {
    final chosenFriend = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const FriendsScreen()),
    );
    if (chosenFriend == null || !context.mounted) return;
    await _openConversation(context, ref, chosenFriend);
  }

  Future<void> _openConversation(BuildContext context, WidgetRef ref, String otherUsername) async {
    // Always ask for the code — it's never cached or skipped, by design.
    final code = await _promptForCode(context, otherUsername);
    if (code == null || code.isEmpty) return;

    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ChatScreen(otherUsername: otherUsername, code: code)),
    );
    // Opening the chat just marked its messages read server-side.
    ref.invalidate(unreadCountsProvider);
  }

  Future<String?> _promptForCode(BuildContext context, String otherUsername) {
    final controller = TextEditingController();
    bool obscure = true;
    return showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Shared code for $otherUsername'),
          content: TextField(
            controller: controller,
            autofocus: true,
            obscureText: obscure,
            style: mono(context, color: AppColors.paper, size: 15),
            decoration: InputDecoration(
              labelText: 'Code',
              suffixIcon: IconButton(
                icon: Icon(
                  obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: AppColors.mist,
                ),
                onPressed: () => setState(() => obscure = !obscure),
              ),
            ),
            onSubmitted: (value) => Navigator.of(context).pop(value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Open'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyConversations extends StatelessWidget {
  const _EmptyConversations({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('> inbox_empty', style: mono(context, color: AppColors.moss)),
            const SizedBox(height: 16),
            Text(
              'No conversations yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Text(
              'Start a chat with someone to begin messaging securely.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.mist),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.add_rounded),
              label: const Text('New chat'),
            ),
          ],
        ),
      ),
    );
  }
}
