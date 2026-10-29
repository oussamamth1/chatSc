import 'dart:typed_data';

enum MessageType { text, image, voice }

MessageType _typeFromJson(String? raw) {
  switch (raw) {
    case 'image':
      return MessageType.image;
    case 'voice':
      return MessageType.voice;
    default:
      return MessageType.text;
  }
}

String messageTypeToJson(MessageType type) {
  switch (type) {
    case MessageType.image:
      return 'image';
    case MessageType.voice:
      return 'voice';
    case MessageType.text:
      return 'text';
  }
}

class ChatMessage {
  final String id;
  final String from;
  final String ciphertext;
  final MessageType type;
  final DateTime createdAt;
  final DateTime? readAt;
  final String? plaintext;
  final Uint8List? mediaBytes;
  final bool decryptFailed;

  const ChatMessage({
    required this.id,
    required this.from,
    required this.ciphertext,
    required this.createdAt,
    this.readAt,
    this.type = MessageType.text,
    this.plaintext,
    this.mediaBytes,
    this.decryptFailed = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final readAt = json['readAt'] as String?;
    return ChatMessage(
      id: json['id'] as String,
      from: json['from'] as String,
      ciphertext: json['ciphertext'] as String,
      type: _typeFromJson(json['type'] as String?),
      createdAt: DateTime.parse(json['createdAt'] as String),
      readAt: readAt == null ? null : DateTime.parse(readAt),
    );
  }

  ChatMessage withTextResult(String? plaintext) {
    return ChatMessage(
      id: id,
      from: from,
      ciphertext: ciphertext,
      type: type,
      createdAt: createdAt,
      readAt: readAt,
      plaintext: plaintext ?? '⚠️ Could not decrypt (wrong code?)',
      decryptFailed: plaintext == null,
    );
  }

  ChatMessage withMediaResult(Uint8List? bytes) {
    return ChatMessage(
      id: id,
      from: from,
      ciphertext: ciphertext,
      type: type,
      createdAt: createdAt,
      readAt: readAt,
      mediaBytes: bytes,
      plaintext: bytes == null ? '⚠️ Could not decrypt (wrong code?)' : null,
      decryptFailed: bytes == null,
    );
  }

  /// Returns a copy with [readAt] set to now — used when a live
  /// `message:read` event confirms the other person has opened the chat.
  ChatMessage markRead() {
    return ChatMessage(
      id: id,
      from: from,
      ciphertext: ciphertext,
      type: type,
      createdAt: createdAt,
      readAt: DateTime.now(),
      plaintext: plaintext,
      mediaBytes: mediaBytes,
      decryptFailed: decryptFailed,
    );
  }
}
