import 'dart:io';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

class VoiceRecorderService {
  final AudioRecorder _audioRecorder = AudioRecorder();

  Future<bool> hasPermission() async {
    return await _audioRecorder.hasPermission();
  }

  Future<void> start({required String path}) async {
    // We need to ensure the directory exists
    final dir = Directory(path).parent;
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    
    await _audioRecorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: path,
    );
  }

  Future<String?> stop() async {
    return await _audioRecorder.stop();
  }

  Future<void> cancel() async {
    if (await isRecording()) {
       await _audioRecorder.stop();
       // Optionally delete the file if needed, but stop returns the path
    }
  }

  Future<bool> isRecording() async {
    return await _audioRecorder.isRecording();
  }
  
  Future<void> dispose() async {
    _audioRecorder.dispose();
  }

  Future<String> getTemporaryPath() async {
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${tempDir.path}/voice_note_$timestamp.m4a';
  }
}
