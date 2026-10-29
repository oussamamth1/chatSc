import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../data/chat_message.dart';
import '../data/chat_socket_service.dart';
import '../data/crypto_service.dart';
import 'auth_providers.dart';
import 'conversations_providers.dart';

typedef ChatParams = ({String otherUsername, String code});

const _wrongCodeAttemptLimit = 2;

String _conversationId(String a, String b) {
  final sorted = [a.toLowerCase(), b.toLowerCase()]..sort();
  return sorted.join('::');
}

enum ChatStatus { connecting, connected, error }

class ChatState {
  final ChatStatus status;
  final List<ChatMessage> messages;
  final String? errorMessage;
  final bool removedDueToWrongCode;

  const ChatState({
    this.status = ChatStatus.connecting,
    this.messages = const [],
    this.errorMessage,
    this.removedDueToWrongCode = false,
  });

  ChatState copyWith({
    ChatStatus? status,
    List<ChatMessage>? messages,
    String? errorMessage,
    bool? removedDueToWrongCode,
  }) {
    return ChatState(
      status: status ?? this.status,
      messages: messages ?? this.messages,
      errorMessage: errorMessage,
      removedDueToWrongCode: removedDueToWrongCode ?? this.removedDueToWrongCode,
    );
  }
}

class ChatController extends StateNotifier<ChatState> {
  ChatController({
    required this.ref,
    required this.me,
    required this.otherUsername,
    required this.code,
    required this.token,
  }) : super(const ChatState()) {
    _init();
  }

  final Ref ref;
  final String me;
  final String otherUsername;
  final String code;
  final String token;

  final _socketService = ChatSocketService();
  final _crypto = CryptoService();
  SecretKey? _key;

  String get _otherKey => otherUsername.toLowerCase();

  Future<void> _init() async {
    _key = await _crypto.deriveKey(
      code: code,
      conversationId: _conversationId(me, otherUsername),
    );

    _socketService.connect(
      baseUrl: kApiBaseUrl,
      token: token,
      otherUsername: otherUsername,
      onHistory: (history) async {
        final decrypted = await Future.wait(
          history.map((raw) => _decryptIncoming(raw as Map<String, dynamic>)),
        );
        state = state.copyWith(status: ChatStatus.connected, messages: decrypted);
        _evaluateCode(decrypted);
        _markIncomingAsReadIfAny(decrypted);
      },
      onMessage: (raw) async {
        final message = await _decryptIncoming(raw);
        state = state.copyWith(messages: [...state.messages, message]);
        _markIncomingAsReadIfAny([message]);
      },
      onMessageRead: (ids) {
        state = state.copyWith(
          messages: [
            for (final m in state.messages) ids.contains(m.id) ? m.markRead() : m,
          ],
        );
      },
      onError: () {
        state = state.copyWith(status: ChatStatus.error, errorMessage: 'Connection error');
      },
    );
  }

  /// Opening the chat (or receiving a message while it's already open) means
  /// the other person's messages were just seen — tell the server so their
  /// sent-message ticks can flip.
  void _markIncomingAsReadIfAny(List<ChatMessage> messages) {
    final hasUnread = messages.any((m) => m.from == _otherKey && m.readAt == null);
    if (hasUnread) _socketService.markRead(otherUsername);
  }

  /// Checks whether existing history suggests the code is wrong (every
  /// message present failed to decrypt). Only existing history is a reliable
  /// signal — a message you send yourself always "decrypts" locally even
  /// with a wrong code, since you'd be using that same wrong key both ways.
  void _evaluateCode(List<ChatMessage> history) {
    final attempts = ref.read(wrongCodeAttemptsProvider);

    if (history.isEmpty) {
      // Nothing to verify against yet; treat as fine.
      _confirmCodeCorrect();
      return;
    }

    final allFailed = history.every((m) => m.decryptFailed);
    if (!allFailed) {
      _confirmCodeCorrect();
      return;
    }

    final nextCount = (attempts[_otherKey] ?? 0) + 1;
    if (nextCount >= _wrongCodeAttemptLimit) {
      ref.read(wrongCodeAttemptsProvider.notifier).update((map) => {...map, _otherKey: 0});
      ref.read(conversationsControllerProvider.notifier).removeConversation(otherUsername);
      state = state.copyWith(
        status: ChatStatus.error,
        errorMessage: 'Wrong code entered twice — conversation removed.',
        removedDueToWrongCode: true,
      );
    } else {
      ref.read(wrongCodeAttemptsProvider.notifier).update((map) => {...map, _otherKey: nextCount});
      state = state.copyWith(
        status: ChatStatus.error,
        errorMessage: 'That code looks wrong — messages could not be decrypted.',
      );
    }
  }

  void _confirmCodeCorrect() {
    ref.read(wrongCodeAttemptsProvider.notifier).update((map) => {...map, _otherKey: 0});
    ref.read(conversationsControllerProvider.notifier).addConversation(otherUsername);
  }

  Future<ChatMessage> _decryptIncoming(Map<String, dynamic> raw) async {
    final message = ChatMessage.fromJson(raw);
    if (message.type == MessageType.text) {
      final plaintext = await _crypto.decrypt(message.ciphertext, _key!);
      return message.withTextResult(plaintext);
    }
    final bytes = await _crypto.decryptBytes(message.ciphertext, _key!);
    return message.withMediaResult(bytes);
  }

  Future<void> sendMessage(String plaintext) async {
    if (plaintext.trim().isEmpty || _key == null) return;
    final ciphertext = await _crypto.encrypt(plaintext.trim(), _key!);
    _socketService.sendMessage(otherUsername, ciphertext);
  }

  Future<void> sendImage(List<int> bytes) async {
    if (_key == null) return;
    final ciphertext = await _crypto.encryptBytes(bytes, _key!);
    _socketService.sendMessage(otherUsername, ciphertext, type: 'image');
  }

  Future<void> sendVoice(List<int> bytes) async {
    if (_key == null) return;
    final ciphertext = await _crypto.encryptBytes(bytes, _key!);
    _socketService.sendMessage(otherUsername, ciphertext, type: 'voice');
  }

  @override
  void dispose() {
    _socketService.dispose();
    super.dispose();
  }
}

final chatControllerProvider =
    StateNotifierProvider.autoDispose.family<ChatController, ChatState, ChatParams>((ref, params) {
  // A snapshot, not a live subscription — see profile_providers.dart for why.
  final auth = ref.read(authControllerProvider);
  return ChatController(
    ref: ref,
    me: auth.username!,
    otherUsername: params.otherUsername,
    code: params.code,
    token: auth.token!,
  );
});
