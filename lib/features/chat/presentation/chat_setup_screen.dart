import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import 'chat_screen.dart';

class ChatSetupScreen extends ConsumerStatefulWidget {
  const ChatSetupScreen({super.key});

  @override
  ConsumerState<ChatSetupScreen> createState() => _ChatSetupScreenState();
}

class _ChatSetupScreenState extends ConsumerState<ChatSetupScreen> {
  final _otherUsernameController = TextEditingController();
  final _codeController = TextEditingController();
  bool _obscureCode = true;

  @override
  void dispose() {
    _otherUsernameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New chat')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('> new_dispatch', style: mono(context, color: AppColors.moss)),
                  const SizedBox(height: 10),
                  Text(
                    'Start a conversation',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 24),
                  DispatchPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _otherUsernameController,
                          decoration: const InputDecoration(labelText: 'Chat with', hintText: 'username'),
                          autocorrect: false,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _codeController,
                          style: mono(context, color: AppColors.paper, size: 15),
                          decoration: InputDecoration(
                            labelText: 'Shared code',
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureCode ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                color: AppColors.mist,
                              ),
                              onPressed: () => setState(() => _obscureCode = !_obscureCode),
                            ),
                          ),
                          obscureText: _obscureCode,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _start(),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Agree on this code with the other person beforehand. '
                          'It encrypts every message on your device — the server never sees it.',
                          style: TextStyle(fontSize: 12.5, color: AppColors.mist, height: 1.4),
                        ),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: _start,
                          child: const Text('Start chat'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _start() {
    final other = _otherUsernameController.text.trim();
    final code = _codeController.text;
    if (other.isEmpty || code.isEmpty) return;

    // ChatController adds the conversation to the list once it confirms the
    // code actually works. The code itself is never cached — always re-asked.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ChatScreen(otherUsername: other, code: code),
      ),
    );
  }
}
