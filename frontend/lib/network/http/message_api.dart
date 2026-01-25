import 'dart:convert';
import 'dart:typed_data';
import 'api_client.dart';

class MessageApi {
  final _client = ApiClient.instance;

  Future<void> sendMessage({
    required String recipientUserId,
    required Uint8List encryptedMessage,
  }) async {
    final ciphertextBase64 = base64Encode(encryptedMessage);
    
    await _client.post('/messages/send', data: {
      'recipient': recipientUserId,
      'ciphertext': ciphertextBase64,
    });
  }

  Future<List<Uint8List>> receiveMessages(String userId) async {
    final response = await _client.get('/messages/receive/$userId');
    
    final messages = (response.data as List)
      .map((msg) => base64Decode(msg['ciphertext'] as String))
      .toList();
    
    return messages;
  }

  // NEW: Tells the backend to delete messages between these two users
Future<void> clearConversation(String userId, String otherUserId) async {
    try {
      // Using query parameters instead of a 'data' body
      // This assumes your backend looks for ?userId=...&otherUserId=...
      await _client.delete(
        '/messages/clear?userId=$userId&otherUserId=$otherUserId'
      );
      print('✅ Server-side deletion requested via URL params');
    } catch (e) {
      print('❌ Failed to clear messages on server: $e');
      rethrow;
    }
}}