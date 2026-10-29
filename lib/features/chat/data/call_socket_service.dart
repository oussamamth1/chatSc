import 'package:socket_io_client/socket_io_client.dart' as io;

/// Callbacks for every call-signaling event the server can relay. The actual
/// audio never flows through this socket — only invite/accept/hangup state
/// and the WebRTC handshake (SDP + ICE candidates) needed to set up a
/// separate, independently-encrypted peer connection.
class CallSocketHandlers {
  const CallSocketHandlers({
    required this.onIncoming,
    required this.onRinging,
    required this.onAccepted,
    required this.onDeclined,
    required this.onCancelled,
    required this.onEnded,
    required this.onBusy,
    required this.onUnavailable,
    required this.onOffer,
    required this.onAnswer,
    required this.onIceCandidate,
  });

  final void Function(String callId, String from) onIncoming;
  final void Function(String callId) onRinging;
  final void Function(String callId) onAccepted;
  final void Function(String callId) onDeclined;
  final void Function(String callId) onCancelled;
  final void Function(String callId) onEnded;
  final void Function() onBusy;
  final void Function(String to) onUnavailable;
  final void Function(String callId, String sdp) onOffer;
  final void Function(String callId, String sdp) onAnswer;
  final void Function(String callId, Map<String, dynamic> candidate) onIceCandidate;
}

/// A connection kept alive for the whole logged-in session (not tied to any
/// one conversation screen) so a call can ring in from anywhere in the app.
class CallSocketService {
  io.Socket? _socket;

  void connect({required String baseUrl, required String token, required CallSocketHandlers handlers}) {
    final socket = io.io(
      baseUrl,
      io.OptionBuilder().setTransports(['websocket']).setAuth({'token': token}).enableForceNew().build(),
    );
    _socket = socket;

    socket.on('call:incoming', (data) {
      final map = data as Map<String, dynamic>;
      handlers.onIncoming(map['callId'] as String, map['from'] as String);
    });
    socket.on('call:ringing', (data) => handlers.onRinging((data as Map)['callId'] as String));
    socket.on('call:accepted', (data) => handlers.onAccepted((data as Map)['callId'] as String));
    socket.on('call:declined', (data) => handlers.onDeclined((data as Map)['callId'] as String));
    socket.on('call:cancelled', (data) => handlers.onCancelled((data as Map)['callId'] as String));
    socket.on('call:ended', (data) => handlers.onEnded((data as Map)['callId'] as String));
    socket.on('call:busy', (_) => handlers.onBusy());
    socket.on('call:unavailable', (data) => handlers.onUnavailable((data as Map)['to'] as String));
    socket.on('call:offer', (data) {
      final map = data as Map<String, dynamic>;
      handlers.onOffer(map['callId'] as String, map['sdp'] as String);
    });
    socket.on('call:answer', (data) {
      final map = data as Map<String, dynamic>;
      handlers.onAnswer(map['callId'] as String, map['sdp'] as String);
    });
    socket.on('call:ice-candidate', (data) {
      final map = data as Map<String, dynamic>;
      handlers.onIceCandidate(map['callId'] as String, Map<String, dynamic>.from(map['candidate'] as Map));
    });
  }

  void invite(String to) => _socket?.emit('call:invite', {'to': to});
  void accept(String callId) => _socket?.emit('call:accept', {'callId': callId});
  void decline(String callId) => _socket?.emit('call:decline', {'callId': callId});
  void cancel(String callId) => _socket?.emit('call:cancel', {'callId': callId});
  void hangup(String callId) => _socket?.emit('call:hangup', {'callId': callId});
  void sendOffer(String callId, String sdp) => _socket?.emit('call:offer', {'callId': callId, 'sdp': sdp});
  void sendAnswer(String callId, String sdp) => _socket?.emit('call:answer', {'callId': callId, 'sdp': sdp});
  void sendIceCandidate(String callId, Map<String, dynamic> candidate) =>
      _socket?.emit('call:ice-candidate', {'callId': callId, 'candidate': candidate});

  void dispose() {
    _socket?.dispose();
    _socket = null;
  }
}
