import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants.dart';

/// Matches `AuthController._tokenKey` — read directly here since the
/// background isolate below has no Riverpod `ProviderScope` to pull it from.
const _tokenKey = 'chat_token';

/// Shows the native incoming-call UI (ringtone, vibration, full-screen
/// accept/decline) for a call. Used both when a push wakes the app and when
/// the live socket delivers `call:incoming` directly — an incoming call
/// should ring the same way either way, instead of only the push path
/// getting a ringtone and the live-socket path getting nothing at all.
Future<void> showIncomingCallUI({required String callId, required String from}) {
  return FlutterCallkitIncoming.showCallkitIncoming(
    CallKitParams(
      id: callId,
      nameCaller: from,
      appName: 'Cipher',
      handle: from,
      type: 0,
      extra: {'callId': callId, 'from': from},
      android: const AndroidParams(
        isCustomNotification: true,
        isShowLogo: false,
        ringtonePath: 'system_ringtone_default',
        backgroundColor: '#121A2A',
        actionColor: '#4CAF50',
        incomingCallNotificationChannelName: 'Incoming calls',
      ),
    ),
  );
}

/// Turns a call-signaling push into the native incoming-call UI (or clears
/// it). Shared by the foreground and background paths so both behave
/// identically.
Future<void> _handleCallPush(Map<String, dynamic> data) async {
  debugPrint('[push] data message received: $data');
  switch (data['type']) {
    case 'invite':
      await showIncomingCallUI(callId: data['callId'] as String, from: data['from'] as String);
      break;
    case 'cancelled':
      await FlutterCallkitIncoming.endCall(data['callId'] as String);
      break;
    default:
      debugPrint('[push] unrecognized or missing data["type"]: ${data['type']}');
  }
}

/// Runs in Android's headless background isolate whenever a call push
/// arrives while the app isn't in the foreground — including fully killed.
/// Must be a top-level/static function per the firebase_messaging contract.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await _handleCallPush(message.data);
}

/// Handles a CallKit "decline" action firing while the app isn't running —
/// there's no live CallController/socket to use, so this reaches the
/// backend directly over plain HTTP instead.
@pragma('vm:entry-point')
Future<void> callkitBackgroundHandler(CallEvent event) async {
  if (event is! CallEventActionCallDecline) return;
  final callId = event.callKitParams.id;
  final prefs = await SharedPreferences.getInstance();
  final authToken = prefs.getString(_tokenKey);
  if (authToken == null) return;
  try {
    await Dio(BaseOptions(baseUrl: kApiBaseUrl)).post<void>(
      '/chat/calls/$callId/decline',
      options: Options(headers: {'Authorization': 'Bearer $authToken'}),
    );
  } catch (_) {
    // Best-effort — if this is lost the invite just times out server-side.
  }
}

/// Registers this device for call-wake pushes and keeps the token in sync.
class PushService {
  Future<void> requestPermission() async {
    await FlutterCallkitIncoming.requestNotificationPermission({
      'title': 'Notification permission',
      'rationaleMessagePermission': 'Notification permission is required so incoming calls can ring.',
      'postNotificationMessageRequired':
          "Please allow notifications from Settings so you don't miss calls.",
    });
    await FlutterCallkitIncoming.requestFullIntentPermission();
  }

  Future<void> registerToken({required String authToken}) async {
    // Deliberately using the classic registration token API (not the newer
    // register()/onRegistered Installation-ID flow) — it's what the
    // backend's firebase-admin `send({token})` call expects.
    // ignore: deprecated_member_use
    final fcmToken = await FirebaseMessaging.instance.getToken();
    debugPrint('[push] FirebaseMessaging.getToken() -> ${fcmToken == null ? 'null' : '${fcmToken.length} chars'}');
    if (fcmToken != null) await _patchToken(authToken, fcmToken);
    // ignore: deprecated_member_use
    FirebaseMessaging.instance.onTokenRefresh.listen((t) => _patchToken(authToken, t));
  }

  Future<void> _patchToken(String authToken, String fcmToken) async {
    try {
      await Dio(BaseOptions(baseUrl: kApiBaseUrl)).patch<void>(
        '/me/fcm-token',
        data: {'token': fcmToken},
        options: Options(headers: {'Authorization': 'Bearer $authToken'}),
      );
      debugPrint('[push] token registered with backend');
    } catch (e) {
      debugPrint('[push] token registration failed: $e');
      // Best-effort — a failed sync here just means this device falls back
      // to foreground-only calls until the next successful registration.
    }
  }
}

/// Lets a push that happens to arrive while the app is already in the
/// foreground (rare — the live socket normally covers that case) still show
/// the same native UI, so the behavior doesn't depend on timing.
void handleForegroundCallPush(RemoteMessage message) {
  _handleCallPush(message.data);
}
