import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../data/friend_profile.dart';
import '../data/friend_request.dart';
import '../providers/friends_providers.dart';

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  final Set<String> _requestedThisSession = {};

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      ref.read(friendsControllerProvider.notifier).search(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(friendsControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Friends')),
      body: RefreshIndicator(
        color: AppColors.signal,
        backgroundColor: AppColors.panel,
        onRefresh: () => ref.read(friendsControllerProvider.notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: const InputDecoration(
                labelText: 'Find people',
                hintText: 'Search by username',
              ),
              autocorrect: false,
            ),
            if (state.searchResults.isNotEmpty) ...[
              const SizedBox(height: 16),
              DispatchPanel(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (final profile in state.searchResults)
                      _PersonRow(
                        profile: profile,
                        trailing: _searchTrailing(state, profile),
                      ),
                  ],
                ),
              ),
            ],
            if (state.incoming.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text('Requests', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              DispatchPanel(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [for (final request in state.incoming) _IncomingRequestTile(request: request)],
                ),
              ),
            ],
            const SizedBox(height: 24),
            Text('Friends', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            if (state.friends.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No friends yet — search above to send an invitation.',
                  style: TextStyle(color: AppColors.mist),
                ),
              )
            else
              DispatchPanel(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (final profile in state.friends)
                      _PersonRow(
                        profile: profile,
                        showStatusLine: true,
                        onTap: () => Navigator.of(context).pop(profile.username),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _searchTrailing(FriendsState state, FriendProfile profile) {
    final alreadySent = _requestedThisSession.contains(profile.username.toLowerCase());
    final alreadyFriend = state.friends.any((f) => f.username.toLowerCase() == profile.username.toLowerCase());
    if (alreadyFriend) return const Text('Friends', style: TextStyle(color: AppColors.mist));
    if (alreadySent) return const Text('Sent', style: TextStyle(color: AppColors.mist));
    return TextButton(
      onPressed: () => _sendRequest(profile.username),
      child: const Text('Add'),
    );
  }

  Future<void> _sendRequest(String username) async {
    final error = await ref.read(friendsControllerProvider.notifier).sendRequest(username);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    } else {
      setState(() => _requestedThisSession.add(username.toLowerCase()));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invitation sent to $username')));
    }
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.profile, this.trailing, this.showStatusLine = false, this.onTap});

  final FriendProfile profile;
  final Widget? trailing;
  final bool showStatusLine;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            InitialTile(
              label: profile.username,
              size: 38,
              accent: profile.online ? AppColors.moss : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(profile.username, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    showStatusLine && profile.online ? 'online' : profile.status,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: mono(
                      context,
                      size: 11.5,
                      color: showStatusLine && profile.online ? AppColors.moss : AppColors.mist,
                    ),
                  ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

class _IncomingRequestTile extends ConsumerWidget {
  const _IncomingRequestTile({required this.request});

  final FriendRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          InitialTile(label: request.from, size: 38),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(request.from, style: const TextStyle(fontWeight: FontWeight.w600)),
                const Text('wants to connect', style: TextStyle(fontSize: 11.5, color: AppColors.mist)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: AppColors.danger),
            tooltip: 'Decline',
            onPressed: () => ref.read(friendsControllerProvider.notifier).decline(request.id),
          ),
          IconButton(
            icon: const Icon(Icons.check_rounded, color: AppColors.moss),
            tooltip: 'Accept',
            onPressed: () => ref.read(friendsControllerProvider.notifier).accept(request.id),
          ),
        ],
      ),
    );
  }
}
