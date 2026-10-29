import 'package:socket_io_client/socket_io_client.dart' as io;

/// Thin wrapper around the socket.IO connection to the chat gateway.
/// Only ever carries ciphertext over the wire.
class ChatSocketService {
  io.Socket? _socket;

  void connect({
    required String baseUrl,
    required String token,
    required String otherUsername,
    required void Function(List<dynamic> history) onHistory,
    required void Function(Map<String, dynamic> message) onMessage,
    required void Function(List<String> messageIds) onMessageRead,
    required void Function() onError,
  }) {
    final socket = io.io(
      baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableForceNew()
          .build(),
    );
    _socket = socket;

    socket.onConnect((_) {
      socket.emit('joinConversation', {'otherUsername': otherUsername});
    });
    socket.on('history', (data) => onHistory(data as List<dynamic>));
    socket.on('message', (data) => onMessage(data as Map<String, dynamic>));
    socket.on('message:read', (data) {
      final ids = (data as Map)['messageIds'] as List<dynamic>;
      onMessageRead(ids.cast<String>());
    });
    socket.onConnectError((_) => onError());
    socket.onError((_) => onError());
  }

  void sendMessage(String to, String ciphertext, {String type = 'text'}) {
    _socket?.emit('sendMessage', {'to': to, 'ciphertext': ciphertext, 'type': type});
  }

  void markRead(String otherUsername) {
    _socket?.emit('markRead', {'otherUsername': otherUsername});
  }

  void dispose() {
    _socket?.dispose();
    _socket = null;
  }
}
