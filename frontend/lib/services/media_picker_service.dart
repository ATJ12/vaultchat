import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../features/chat/message_model.dart';

class MediaPickerService {
  final _imagePicker = ImagePicker();

  Future<ChatMessage?> pickImage({
    required String senderId,
    required String recipientId,
    int? burnAfterSeconds,
  }) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image == null) return null;

      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);

      return ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: '[Image]',
        senderId: senderId,
        recipientId: recipientId,
        timestamp: DateTime.now(),
        type: MessageType.image,
        fileData: base64Image,
        fileName: image.name,
        mimeType: 'image/${image.path.split('.').last}',
        fileSize: bytes.length,
        burnAfterSeconds: burnAfterSeconds,
      );
    } catch (e) {
      print('Error picking image: $e');
      return null;
    }
  }

  Future<ChatMessage?> pickFile({
    required String senderId,
    required String recipientId,
    int? burnAfterSeconds,
  }) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: true, // Important for web!
      );

      if (result == null || result.files.isEmpty) return null;

      final file = result.files.first;
      
      // Get bytes - works on both web and mobile
      Uint8List? bytes;
      if (kIsWeb) {
        bytes = file.bytes;
      } else {
        if (file.path != null) {
          // On mobile, read from path
          bytes = await file.bytes;
        }
      }

      if (bytes == null) {
        throw Exception('Could not read file');
      }

      // Limit file size to 10MB
      if (bytes.length > 10 * 1024 * 1024) {
        throw Exception('File too large (max 10MB)');
      }

      final base64File = base64Encode(bytes);

      return ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: '[File: ${file.name}]',
        senderId: senderId,
        recipientId: recipientId,
        timestamp: DateTime.now(),
        type: MessageType.file,
        fileData: base64File,
        fileName: file.name,
        mimeType: file.extension != null ? 'application/${file.extension}' : 'application/octet-stream',
        fileSize: bytes.length,
        burnAfterSeconds: burnAfterSeconds,
      );
    } catch (e) {
      print('Error picking file: $e');
      rethrow;
    }
  }

  Future<ChatMessage?> recordAudio({
    required String senderId,
    required String recipientId,
    int? burnAfterSeconds,
  }) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
        withData: true, // Important for web!
      );

      if (result == null || result.files.isEmpty) return null;

      final file = result.files.first;
      
      // Get bytes - works on both web and mobile
      Uint8List? bytes;
      if (kIsWeb) {
        bytes = file.bytes;
      } else {
        bytes = await file.bytes;
      }

      if (bytes == null) {
        throw Exception('Could not read audio file');
      }

      // Limit audio size to 5MB
      if (bytes.length > 5 * 1024 * 1024) {
        throw Exception('Audio too large (max 5MB)');
      }

      final base64Audio = base64Encode(bytes);

      return ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: '[Audio: ${file.name}]',
        senderId: senderId,
        recipientId: recipientId,
        timestamp: DateTime.now(),
        type: MessageType.audio,
        fileData: base64Audio,
        fileName: file.name,
        mimeType: 'audio/${file.extension ?? 'mp3'}',
        fileSize: bytes.length,
        burnAfterSeconds: burnAfterSeconds,
      );
    } catch (e) {
      print('Error picking audio: $e');
      rethrow;
    }
  }
}