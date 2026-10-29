import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme.dart';
import '../data/chat_message.dart';
import '../data/user_profile.dart';
import '../data/voice_recorder_service.dart';
import '../providers/auth_providers.dart';
import '../providers/call_providers.dart';
import '../providers/chat_providers.dart';
import '../providers/profile_providers.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.otherUsername, required this.code});

  final String otherUsername;
  final String code;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _imagePicker = ImagePicker();
  final _voiceRecorder = VoiceRecorderService();

  bool _hasText = false;
  bool _isRecording = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;

  ChatParams get _params => (otherUsername: widget.otherUsername, code: widget.code);

  @override
  void initState() {
    super.initState();
    _messageController.addListener(() {
      final hasText = _messageController.text.trim().isNotEmpty;
      if (hasText != _hasText) setState(() => _hasText = hasText);
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _voiceRecorder.dispose();
    _recordTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatControllerProvider(_params));
    final me = ref.watch(authControllerProvider).username;
    final otherProfile = ref.watch(otherUserProfileProvider(widget.otherUsername));

    ref.listen(chatControllerProvider(_params), (previous, next) {
      if (next.removedDueToWrongCode && previous?.removedDueToWrongCode != true) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(next.errorMessage ?? 'Wrong code entered twice — conversation removed.')),
          );
        });
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    });

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InitialTile(
              label: widget.otherUsername,
              size: 34,
              accent: otherProfile.valueOrNull?.online == true ? AppColors.moss : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.otherUsername, overflow: TextOverflow.ellipsis),
                  _buildSubtitle(chat, otherProfile),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Call',
            icon: const Icon(Icons.call_outlined),
            onPressed: () => ref.read(callControllerProvider.notifier).startCall(widget.otherUsername),
          ),
        ],
        bottom: chat.status == ChatStatus.connecting
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2, backgroundColor: AppColors.line),
              )
            : null,
      ),
      body: Column(
        children: [
          if (chat.status == ChatStatus.error)
            Container(
              width: double.infinity,
              color: AppColors.danger.withValues(alpha: 0.14),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, size: 18, color: AppColors.danger),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      chat.errorMessage ?? 'Connection error',
                      style: const TextStyle(color: AppColors.danger),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: chat.messages.isEmpty && chat.status == ChatStatus.connected
                ? _EmptyState(otherUsername: widget.otherUsername)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    itemCount: chat.messages.length,
                    itemBuilder: (context, index) {
                      final message = chat.messages[index];
                      final isMe = message.from == me;
                      return _MessageBubble(message: message, isMe: isMe);
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 12, 12),
              child: _isRecording ? _buildRecordingRow() : _buildInputRow(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        IconButton(
          tooltip: 'Send image',
          icon: const Icon(Icons.add_photo_alternate_outlined, color: AppColors.mist),
          onPressed: _pickImage,
        ),
        Expanded(
          child: Container(
            constraints: const BoxConstraints(maxHeight: 120),
            decoration: BoxDecoration(
              color: AppColors.raised,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.line),
            ),
            child: TextField(
              controller: _messageController,
              minLines: 1,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Message',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onSubmitted: (_) => _send(),
              textInputAction: TextInputAction.send,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          decoration: BoxDecoration(color: AppColors.signal, borderRadius: BorderRadius.circular(10)),
          child: IconButton(
            onPressed: _hasText ? _send : _startRecording,
            icon: Icon(
              _hasText ? Icons.arrow_upward_rounded : Icons.mic_rounded,
              color: AppColors.onSignal,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecordingRow() {
    final minutes = (_recordSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_recordSeconds % 60).toString().padLeft(2, '0');
    return Row(
      children: [
        IconButton(
          tooltip: 'Cancel',
          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
          onPressed: _cancelRecording,
        ),
        Expanded(
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Text('Recording  $minutes:$seconds', style: mono(context, color: AppColors.paper)),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(color: AppColors.signal, borderRadius: BorderRadius.circular(10)),
          child: IconButton(
            tooltip: 'Send',
            onPressed: _stopRecording,
            icon: const Icon(Icons.arrow_upward_rounded, color: AppColors.onSignal),
          ),
        ),
      ],
    );
  }

  Widget _buildSubtitle(ChatState chat, AsyncValue<UserProfile> otherProfile) {
    final profile = otherProfile.valueOrNull;
    if (chat.status == ChatStatus.connected && profile != null) {
      return Text(
        profile.online ? 'online' : (profile.status.isEmpty ? 'encrypted' : profile.status),
        overflow: TextOverflow.ellipsis,
        style: mono(
          context,
          size: 11.5,
          color: profile.online ? AppColors.moss : AppColors.mist,
          weight: profile.online ? FontWeight.w600 : FontWeight.w500,
        ),
      );
    }

    return Text(_statusLabel(chat.status), style: mono(context, size: 11.5));
  }

  String _statusLabel(ChatStatus status) {
    switch (status) {
      case ChatStatus.connecting:
        return 'connecting…';
      case ChatStatus.connected:
        return 'encrypted';
      case ChatStatus.error:
        return 'disconnected';
    }
  }

  void _send() {
    final text = _messageController.text;
    if (text.trim().isEmpty) return;
    ref.read(chatControllerProvider(_params).notifier).sendMessage(text);
    _messageController.clear();
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Camera'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Gallery'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picked = await _imagePicker.pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 80,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    await ref.read(chatControllerProvider(_params).notifier).sendImage(bytes);
  }

  Future<void> _startRecording() async {
    final started = await _voiceRecorder.start();
    if (!started) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission is needed to record voice messages')),
      );
      return;
    }
    setState(() {
      _isRecording = true;
      _recordSeconds = 0;
    });
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _recordSeconds++);
    });
  }

  Future<void> _stopRecording() async {
    _recordTimer?.cancel();
    final bytes = await _voiceRecorder.stop();
    setState(() => _isRecording = false);
    if (bytes == null || !mounted) return;
    await ref.read(chatControllerProvider(_params).notifier).sendVoice(bytes);
  }

  Future<void> _cancelRecording() async {
    _recordTimer?.cancel();
    await _voiceRecorder.cancel();
    if (mounted) setState(() => _isRecording = false);
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.otherUsername});

  final String otherUsername;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('> channel_open', style: mono(context, color: AppColors.moss)),
            const SizedBox(height: 14),
            const Text(
              'No messages yet',
              style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.paper),
            ),
            const SizedBox(height: 4),
            Text(
              'Messages with $otherUsername are end-to-end encrypted with your shared code.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.mist),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isMe});

  final ChatMessage message;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isMe ? AppColors.signal : AppColors.panel;
    final onBubbleColor = isMe ? AppColors.onSignal : AppColors.paper;
    final isImage = message.type == MessageType.image && message.mediaBytes != null;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: isImage
            ? const EdgeInsets.all(4)
            : const EdgeInsets.fromLTRB(14, 10, 14, 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isMe ? 14 : 3),
            bottomRight: Radius.circular(isMe ? 3 : 14),
          ),
          border: isMe ? null : Border.all(color: AppColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildContent(context, onBubbleColor),
            Padding(
              padding: EdgeInsets.only(top: 2, right: isImage ? 6 : 0, bottom: isImage ? 4 : 0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatTime(message.createdAt),
                    style: mono(context, size: 10, color: onBubbleColor.withValues(alpha: 0.65)),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    Icon(
                      message.readAt != null ? Icons.done_all_rounded : Icons.check_rounded,
                      size: 13,
                      color: message.readAt != null
                          ? AppColors.signal
                          : onBubbleColor.withValues(alpha: 0.65),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, Color onBubbleColor) {
    switch (message.type) {
      case MessageType.image:
        if (message.mediaBytes == null) {
          return Text(message.plaintext ?? '', style: TextStyle(color: onBubbleColor));
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: GestureDetector(
            onTap: () => _openFullscreen(context, message.mediaBytes!),
            child: Image.memory(message.mediaBytes!, fit: BoxFit.cover),
          ),
        );
      case MessageType.voice:
        if (message.mediaBytes == null) {
          return Text(message.plaintext ?? '', style: TextStyle(color: onBubbleColor));
        }
        return _VoicePlayer(bytes: message.mediaBytes!, color: onBubbleColor);
      case MessageType.text:
        return Text(message.plaintext ?? '', style: TextStyle(color: onBubbleColor));
    }
  }

  void _openFullscreen(BuildContext context, Uint8List bytes) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (context, _, _) => GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: Center(child: InteractiveViewer(child: Image.memory(bytes))),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}

class _VoicePlayer extends StatefulWidget {
  const _VoicePlayer({required this.bytes, required this.color});

  final Uint8List bytes;
  final Color color;

  @override
  State<_VoicePlayer> createState() => _VoicePlayerState();
}

class _VoicePlayerState extends State<_VoicePlayer> {
  final _player = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player.onDurationChanged.listen((d) => mounted ? setState(() => _duration = d) : null);
    _player.onPositionChanged.listen((p) => mounted ? setState(() => _position = p) : null);
    _player.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _isPlaying = false;
        _position = Duration.zero;
      });
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.play(BytesSource(widget.bytes));
    }
    setState(() => _isPlaying = !_isPlaying);
  }

  @override
  Widget build(BuildContext context) {
    final total = _duration.inMilliseconds == 0 ? 1 : _duration.inMilliseconds;
    final progress = (_position.inMilliseconds / total).clamp(0.0, 1.0);
    return SizedBox(
      width: 180,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill, color: widget.color),
            iconSize: 32,
            onPressed: _toggle,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: LinearProgressIndicator(
              value: progress,
              color: widget.color,
              backgroundColor: widget.color.withValues(alpha: 0.25),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _formatDuration(_duration.inMilliseconds == 0 ? _position : _duration),
            style: TextStyle(fontSize: 10.5, color: widget.color),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.toString().padLeft(1, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
