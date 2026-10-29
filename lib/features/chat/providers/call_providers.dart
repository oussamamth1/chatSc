import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';

import '../data/call_socket_service.dart';
import '../data/push_service.dart';

enum CallPhase { idle, outgoingRinging, incomingRinging, connecting, active }

class CallState {
  const CallState({
    this.phase = CallPhase.idle,
    this.callId,
    this.peerUsername,
    this.muted = false,
    this.speakerOn = false,
    this.errorMessage,
    this.connectedAt,
  });

  final CallPhase phase;
  final String? callId;
  final String? peerUsername;
  final bool muted;
  final bool speakerOn;
  final String? errorMessage;
  final DateTime? connectedAt;

  CallState copyWith({
    CallPhase? phase,
    String? callId,
    String? peerUsername,
    bool? muted,
    bool? speakerOn,
    String? errorMessage,
    DateTime? connectedAt,
  }) {
    return CallState(
      phase: phase ?? this.phase,
      callId: callId ?? this.callId,
      peerUsername: peerUsername ?? this.peerUsername,
      muted: muted ?? this.muted,
      speakerOn: speakerOn ?? this.speakerOn,
      errorMessage: errorMessage,
      connectedAt: connectedAt ?? this.connectedAt,
    );
  }
}

/// Google's public STUN server plus a free public TURN relay (Open Relay
/// Project) as a fallback for networks where a direct peer-to-peer path
/// can't be found (common on mobile carrier NATs). Either way the media
/// itself stays end-to-end encrypted by WebRTC (DTLS-SRTP) — a TURN relay
/// only forwards encrypted packets, it can't read them.
const _rtcConfiguration = {
  'iceServers': [
    {'urls': 'stun:stun.l.google.com:19302'},
    {
      'urls': ['turn:openrelay.metered.ca:80', 'turn:openrelay.metered.ca:443'],
      'username': 'openrelayproject',
      'credential': 'openrelayproject',
    },
  ],
};

/// Lives for the whole logged-in session (not per-screen) so an incoming
/// call can ring from anywhere in the app.
class CallController extends StateNotifier<CallState> {
  CallController() : super(const CallState());

  CallSocketService? _socket;
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  final List<RTCIceCandidate> _pendingCandidates = [];
  bool _remoteDescriptionSet = false;
  bool _pendingAutoAccept = false;

  void connect({required String baseUrl, required String token}) {
    if (_socket != null) return;
    _socket = CallSocketService()
      ..connect(
        baseUrl: baseUrl,
        token: token,
        handlers: CallSocketHandlers(
          onIncoming: _onIncoming,
          onRinging: _onRinging,
          onAccepted: _onAccepted,
          onDeclined: (_) => _resetWithMessage('Call declined'),
          onCancelled: (_) => _resetWithMessage('Missed call — cancelled'),
          onEnded: (_) => _resetWithMessage(null),
          onBusy: () => _resetWithMessage("They're on another call"),
          onUnavailable: (_) => _resetWithMessage('That person is offline'),
          onOffer: _onRemoteOffer,
          onAnswer: _onRemoteAnswer,
          onIceCandidate: _onRemoteIceCandidate,
        ),
      );
    if (_pendingAutoAccept) {
      _pendingAutoAccept = false;
      acceptCall();
    }
  }

  /// Seeds incoming-call state without a live `call:incoming` socket event —
  /// used when a CallKit push (not the socket) is what woke the app, so
  /// `_onIncoming` never ran. When [autoAccept] is set (the user already
  /// tapped "Answer" on the native UI before the app was even running),
  /// answers as soon as the socket is available.
  void seedIncomingFromPush({required String callId, required String from, bool autoAccept = false}) {
    if (state.phase != CallPhase.idle && state.callId != callId) return;
    state = CallState(phase: CallPhase.incomingRinging, callId: callId, peerUsername: from);
    if (!autoAccept) return;
    if (_socket != null) {
      acceptCall();
    } else {
      _pendingAutoAccept = true;
    }
  }

  void disconnectSession() {
    if (state.callId != null) FlutterCallkitIncoming.endCall(state.callId!);
    _teardownPeer();
    _socket?.dispose();
    _socket = null;
    state = const CallState();
  }

  Future<void> startCall(String peerUsername) async {
    if (state.phase != CallPhase.idle) return;
    if (!await _ensureMicPermission()) {
      state = state.copyWith(errorMessage: 'Microphone permission is needed to make calls');
      return;
    }
    state = CallState(phase: CallPhase.outgoingRinging, peerUsername: peerUsername);
    debugPrint('[call] inviting $peerUsername');
    _socket?.invite(peerUsername);
  }

  void _onRinging(String callId) {
    if (state.phase != CallPhase.outgoingRinging) return;
    state = state.copyWith(callId: callId);
  }

  Future<void> acceptCall() async {
    if (state.phase != CallPhase.incomingRinging || state.callId == null) return;
    if (!await _ensureMicPermission()) {
      final callId = state.callId!;
      state = state.copyWith(errorMessage: 'Microphone permission is needed to answer calls');
      _socket?.decline(callId);
      FlutterCallkitIncoming.endCall(callId);
      return;
    }
    state = state.copyWith(phase: CallPhase.connecting);
    try {
      await _createPeerConnection();
      debugPrint('[call] accepting ${state.callId}');
      _socket?.accept(state.callId!);
    } catch (e, st) {
      debugPrint('[call] acceptCall failed: $e\n$st');
      _resetWithMessage('Could not start the call: $e');
    }
  }

  void declineCall() {
    if (state.callId != null) {
      _socket?.decline(state.callId!);
      FlutterCallkitIncoming.endCall(state.callId!);
    }
    state = const CallState();
  }

  void hangUp() {
    if (state.callId != null) {
      _socket?.hangup(state.callId!);
      FlutterCallkitIncoming.endCall(state.callId!);
    }
    _teardownPeer();
    state = const CallState();
  }

  void toggleMute() {
    final tracks = _localStream?.getAudioTracks() ?? const [];
    if (tracks.isEmpty) return;
    final track = tracks.first;
    track.enabled = !track.enabled;
    state = state.copyWith(muted: !track.enabled);
  }

  Future<void> toggleSpeaker() async {
    final next = !state.speakerOn;
    await Helper.setSpeakerphoneOn(next);
    state = state.copyWith(speakerOn: next);
  }

  void _onIncoming(String callId, String from) {
    debugPrint('[call] incoming from $from, callId=$callId');
    if (state.phase != CallPhase.idle) {
      // Already on a call — tell the caller rather than silently drop it.
      _socket?.decline(callId);
      return;
    }
    state = CallState(phase: CallPhase.incomingRinging, callId: callId, peerUsername: from);
    // The live socket delivering this has no ringtone/alert of its own —
    // show the same native ringing UI a push-woken call gets, so an
    // incoming call always actually rings instead of just quietly updating
    // state behind whatever screen the app happens to be showing.
    showIncomingCallUI(callId: callId, from: from);
  }

  Future<void> _onAccepted(String callId) async {
    debugPrint('[call] accepted, callId=$callId, matches=${state.callId == callId}');
    if (state.callId != callId) return;
    state = state.copyWith(phase: CallPhase.connecting);
    try {
      await _createPeerConnection();
      final offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);
      debugPrint('[call] sending offer');
      _socket?.sendOffer(callId, offer.sdp!);
    } catch (e, st) {
      debugPrint('[call] _onAccepted failed: $e\n$st');
      _resetWithMessage('Could not start the call: $e');
    }
  }

  Future<void> _onRemoteOffer(String callId, String sdp) async {
    debugPrint('[call] received offer, callId=$callId, haveConnection=${_peerConnection != null}');
    if (state.callId != callId || _peerConnection == null) return;
    try {
      await _peerConnection!.setRemoteDescription(RTCSessionDescription(sdp, 'offer'));
      _remoteDescriptionSet = true;
      await _flushPendingCandidates();
      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);
      debugPrint('[call] sending answer');
      _socket?.sendAnswer(callId, answer.sdp!);
    } catch (e, st) {
      debugPrint('[call] _onRemoteOffer failed: $e\n$st');
      _resetWithMessage('Could not start the call: $e');
    }
  }

  Future<void> _onRemoteAnswer(String callId, String sdp) async {
    debugPrint('[call] received answer, callId=$callId, haveConnection=${_peerConnection != null}');
    if (state.callId != callId || _peerConnection == null) return;
    await _peerConnection!.setRemoteDescription(RTCSessionDescription(sdp, 'answer'));
    _remoteDescriptionSet = true;
    await _flushPendingCandidates();
  }

  Future<void> _onRemoteIceCandidate(String callId, Map<String, dynamic> data) async {
    if (state.callId != callId) return;
    final candidate = RTCIceCandidate(
      data['candidate'] as String?,
      data['sdpMid'] as String?,
      data['sdpMLineIndex'] as int?,
    );
    debugPrint('[call] remote ICE candidate received, remoteDescSet=$_remoteDescriptionSet');
    if (_remoteDescriptionSet && _peerConnection != null) {
      await _peerConnection!.addCandidate(candidate);
    } else {
      _pendingCandidates.add(candidate);
    }
  }

  Future<void> _flushPendingCandidates() async {
    for (final candidate in _pendingCandidates) {
      await _peerConnection?.addCandidate(candidate);
    }
    _pendingCandidates.clear();
  }

  Future<void> _createPeerConnection() async {
    _localStream = await navigator.mediaDevices.getUserMedia({'audio': true, 'video': false});
    final pc = await createPeerConnection(_rtcConfiguration);
    for (final track in _localStream!.getAudioTracks()) {
      await pc.addTrack(track, _localStream!);
    }
    pc.onIceCandidate = (candidate) {
      final callId = state.callId;
      debugPrint('[call] local ICE candidate: ${candidate.candidate != null}, callId=$callId');
      if (callId == null || candidate.candidate == null) return;
      _socket?.sendIceCandidate(callId, {
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    };
    pc.onIceConnectionState = (iceState) {
      debugPrint('[call] ICE connection state: $iceState');
    };
    pc.onIceGatheringState = (gatheringState) {
      debugPrint('[call] ICE gathering state: $gatheringState');
    };
    pc.onConnectionState = (connectionState) {
      debugPrint('[call] peer connection state: $connectionState');
      if (connectionState == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        if (state.phase != CallPhase.active) {
          state = state.copyWith(phase: CallPhase.active, connectedAt: DateTime.now());
          if (state.callId != null) FlutterCallkitIncoming.setCallConnected(state.callId!);
          // Android/iOS route call audio to the earpiece by default, which is
          // silent unless the phone is held to your ear. Default to speaker
          // once the connection is actually up, since this is a chat app,
          // not a dialer — switching output earlier can race with the
          // native audio session still being set up on some devices.
          Helper.setSpeakerphoneOn(true).then((_) {
            state = state.copyWith(speakerOn: true);
          }).catchError((e) {
            debugPrint('[call] setSpeakerphoneOn failed: $e');
          });
        }
      } else if (connectionState == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        if (state.phase != CallPhase.idle) hangUp();
      }
    };
    _peerConnection = pc;
  }

  void _teardownPeer() {
    _peerConnection?.close();
    _peerConnection = null;
    for (final track in _localStream?.getTracks() ?? const []) {
      track.stop();
    }
    _localStream?.dispose();
    _localStream = null;
    _pendingCandidates.clear();
    _remoteDescriptionSet = false;
  }

  void _resetWithMessage(String? message) {
    if (state.callId != null) FlutterCallkitIncoming.endCall(state.callId!);
    _teardownPeer();
    state = CallState(errorMessage: message);
  }

  Future<bool> _ensureMicPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  @override
  void dispose() {
    disconnectSession();
    super.dispose();
  }
}

final callControllerProvider = StateNotifierProvider<CallController, CallState>((ref) {
  return CallController();
});
