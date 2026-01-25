import 'dart:convert';
import 'dart:typed_data';
import 'dart:io'; 
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:http/http.dart' as http; // Use this to fetch Blob bytes on Web
import '../features/chat/message_model.dart';

class AudioRecorderService {
  final _recorder = AudioRecorder();
  bool _isRecording = false;

  bool get isRecording => _isRecording;

  Future<void> startRecording() async {
    try {
      if (await _recorder.hasPermission()) {
        String path = '';
        if (!kIsWeb) {
          final tempDir = await getTemporaryDirectory();
          path = '${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.wav';
        }

        await _recorder.start(
          const RecordConfig(
            encoder: AudioEncoder.wav,
            bitRate: 128000,
            sampleRate: 44100,
          ),
          path: path, 
        );
        _isRecording = true;
      }
    } catch (e) {
      print('Error starting recording: $e');
      rethrow;
    }
  }

  Future<ChatMessage?> stopRecording({
    required String senderId,
    required String recipientId,
    int? burnAfterSeconds,
  }) async {
    try {
      final path = await _recorder.stop();
      _isRecording = false;

      if (path == null) return null;

      final bytes = await _getBytesFromPath(path);
      if (bytes == null) return null;

      return ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: '[Voice Message]',
        senderId: senderId,
        recipientId: recipientId,
        timestamp: DateTime.now(),
        type: MessageType.audio,
        fileData: base64Encode(bytes),
        fileName: 'voice_${DateTime.now().millisecondsSinceEpoch}.wav',
        mimeType: 'audio/wav',
        fileSize: bytes.length,
        burnAfterSeconds: burnAfterSeconds,
      );
    } catch (e) {
      print('Error stopping recording: $e');
      return null;
    }
  }

  Future<Uint8List?> _getBytesFromPath(String path) async {
    try {
      if (kIsWeb) {
        // Handle Blob URLs or data URIs on Web
        final response = await http.get(Uri.parse(path));
        return response.bodyBytes;
      } else {
        return await File(path).readAsBytes();
      }
    } catch (e) {
      print('Error getting bytes: $e');
      return null;
    }
  }

  void cancelRecording() async {
    await _recorder.cancel();
    _isRecording = false;
  }

  void dispose() => _recorder.dispose();
}