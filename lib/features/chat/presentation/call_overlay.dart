import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_keys.dart';
import '../../../core/constants.dart';
import '../data/push_service.dart';
import '../providers/auth_providers.dart';
import '../providers/call_providers.dart';
import 'call_screen.dart';

/// Wraps the whole app. Opens the call-signaling connection once the user is
/// logged in (so a call can ring in from anywhere, not just inside a chat),
/// and pushes/pops the full-screen call UI as the call's phase changes.
class CallOverlay extends ConsumerStatefulWidget {
  const CallOverlay({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<CallOverlay> createState() => _CallOverlayState();
}

class _CallOverlayState extends ConsumerState<CallOverlay> {
  bool _callScreenOpen = false;
  final _pushService = PushService();
  StreamSubscription<CallEvent?>? _callkitEventSub;

  @override
  void initState() {
    super.initState();
    _callkitEventSub = FlutterCallkitIncoming.onEvent.listen(_onCallkitEvent);
    _checkActiveCallkitCall();
  }

  @override
  void dispose() {
    _callkitEventSub?.cancel();
    super.dispose();
  }

  Future<void> _checkActiveCallkitCall() async {
    // Covers a cold start triggered by tapping "Answer" on the native
    // incoming-call UI while the app was fully closed: the Flutter engine
    // (and this widget) didn't exist yet when that tap happened, so there's
    // no event-stream history to replay. `isAccepted` tells us it already
    // happened.
    final calls = await FlutterCallkitIncoming.activeCalls();
    for (final call in calls) {
      if (!call.isAccepted) continue;
      final from = (call.extra?['from'] as String?) ?? call.nameCaller ?? call.handle ?? '';
      ref
          .read(callControllerProvider.notifier)
          .seedIncomingFromPush(callId: call.id, from: from, autoAccept: true);
    }
  }

  void _onCallkitEvent(CallEvent? event) {
    switch (event) {
      case CallEventActionCallAccept(:final callKitParams):
        final from = (callKitParams.extra?['from'] as String?) ?? callKitParams.nameCaller ?? '';
        ref
            .read(callControllerProvider.notifier)
            .seedIncomingFromPush(callId: callKitParams.id, from: from, autoAccept: true);
      case CallEventActionCallDecline():
        ref.read(callControllerProvider.notifier).declineCall();
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      final wasLoggedIn = previous?.status == AuthStatus.loggedIn;
      final isLoggedIn = next.status == AuthStatus.loggedIn;
      if (!wasLoggedIn && isLoggedIn && next.token != null) {
        ref.read(callControllerProvider.notifier).connect(baseUrl: kApiBaseUrl, token: next.token!);
        _pushService.requestPermission();
        _pushService.registerToken(authToken: next.token!);
      } else if (wasLoggedIn && !isLoggedIn) {
        ref.read(callControllerProvider.notifier).disconnectSession();
      }
    });

    ref.listen<CallState>(callControllerProvider, (previous, next) {
      final wasIdle = previous == null || previous.phase == CallPhase.idle;
      final isIdle = next.phase == CallPhase.idle;

      if (wasIdle && !isIdle && !_callScreenOpen) {
        _callScreenOpen = true;
        navigatorKey.currentState
            ?.push(MaterialPageRoute(builder: (_) => const CallScreen(), fullscreenDialog: true))
            .then((_) => _callScreenOpen = false);
      } else if (!wasIdle && isIdle && _callScreenOpen) {
        navigatorKey.currentState?.pop();
      }

      if (next.errorMessage != null && next.errorMessage != previous?.errorMessage) {
        scaffoldMessengerKey.currentState?.showSnackBar(SnackBar(content: Text(next.errorMessage!)));
      }
    });

    return widget.child;
  }
}
