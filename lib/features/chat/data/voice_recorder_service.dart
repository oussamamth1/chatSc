import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class VoiceRecorderService {
  final _recorder = AudioRecorder();
  String? _path;

  Future<bool> start() async {
    if (!await _recorder.hasPermission()) return false;
    final dir = await getTemporaryDirectory();
    _path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: _path!);
    return true;
  }

  /// Stops recording and returns the recorded audio bytes, or null if
  /// nothing was recorded (e.g. cancelled before any audio was captured).
  Future<Uint8List?> stop() async {
    final path = await _recorder.stop() ?? _path;
    _path = null;
    if (path == null) return null;
    final file = File(path);
    if (!await file.exists()) return null;
    final bytes = await file.readAsBytes();
    await file.delete();
    return bytes.isEmpty ? null : bytes;
  }

  Future<void> cancel() async {
    await _recorder.stop();
    if (_path != null) {
      final file = File(_path!);
      if (await file.exists()) await file.delete();
      _path = null;
    }
  }

  void dispose() => _recorder.dispose();
}
