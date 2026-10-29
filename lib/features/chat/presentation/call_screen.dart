import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../providers/call_providers.dart';

/// Full-screen incoming/outgoing/active call UI. Pushed and popped
/// automatically by CallOverlayListener as the call's phase changes — the
/// buttons here only ever tell the controller what happened, they never
/// navigate directly.
class CallScreen extends ConsumerStatefulWidget {
  const CallScreen({super.key});

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  Timer? _ticker;
  Duration _elapsed = Duration.zero;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _ensureTicker(DateTime? connectedAt) {
    if (connectedAt == null || _ticker != null) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed = DateTime.now().difference(connectedAt));
    });
  }

  @override
  Widget build(BuildContext context) {
    final call = ref.watch(callControllerProvider);
    _ensureTicker(call.connectedAt);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) ref.read(callControllerProvider.notifier).hangUp();
      },
      child: Scaffold(
        backgroundColor: AppColors.ink,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
            child: Column(
              children: [
                const Spacer(),
                InitialTile(label: call.peerUsername ?? '?', size: 96),
                const SizedBox(height: 24),
                Text(
                  call.peerUsername ?? '',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Text(_statusLabel(call), style: mono(context, size: 13, color: AppColors.moss)),
                const Spacer(),
                if (call.phase == CallPhase.incomingRinging)
                  _IncomingActions(
                    onDecline: () => ref.read(callControllerProvider.notifier).declineCall(),
                    onAccept: () => ref.read(callControllerProvider.notifier).acceptCall(),
                  )
                else
                  _InCallActions(call: call),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _statusLabel(CallState call) {
    switch (call.phase) {
      case CallPhase.idle:
        return '';
      case CallPhase.outgoingRinging:
        return 'calling…';
      case CallPhase.incomingRinging:
        return 'incoming call';
      case CallPhase.connecting:
        return 'connecting…';
      case CallPhase.active:
        final minutes = _elapsed.inMinutes.toString().padLeft(2, '0');
        final seconds = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
        return '$minutes:$seconds · encrypted';
    }
  }
}

class _IncomingActions extends StatelessWidget {
  const _IncomingActions({required this.onDecline, required this.onAccept});

  final VoidCallback onDecline;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _RoundButton(icon: Icons.call_end_rounded, color: AppColors.danger, onTap: onDecline, label: 'Decline'),
        _RoundButton(icon: Icons.call_rounded, color: AppColors.moss, onTap: onAccept, label: 'Accept'),
      ],
    );
  }
}

class _InCallActions extends ConsumerWidget {
  const _InCallActions({required this.call});

  final CallState call;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(callControllerProvider.notifier);
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _RoundButton(
              icon: call.muted ? Icons.mic_off_rounded : Icons.mic_rounded,
              color: call.muted ? AppColors.signal : AppColors.raised,
              iconColor: call.muted ? AppColors.onSignal : AppColors.paper,
              onTap: notifier.toggleMute,
              label: call.muted ? 'Unmute' : 'Mute',
              small: true,
            ),
            _RoundButton(
              icon: call.speakerOn ? Icons.volume_up_rounded : Icons.hearing_rounded,
              color: call.speakerOn ? AppColors.signal : AppColors.raised,
              iconColor: call.speakerOn ? AppColors.onSignal : AppColors.paper,
              onTap: notifier.toggleSpeaker,
              label: 'Speaker',
              small: true,
            ),
          ],
        ),
        const SizedBox(height: 28),
        _RoundButton(icon: Icons.call_end_rounded, color: AppColors.danger, onTap: notifier.hangUp, label: 'End'),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.label,
    this.iconColor = Colors.white,
    this.small = false,
  });

  final IconData icon;
  final Color color;
  final Color iconColor;
  final VoidCallback onTap;
  final String label;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final size = small ? 56.0 : 72.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: color,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(icon, color: iconColor, size: small ? 24 : 30),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.mist)),
      ],
    );
  }
}
