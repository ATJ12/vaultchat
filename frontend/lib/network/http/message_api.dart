import 'api_client.dart';
import '../../features/chat/message_model.dart';
import '../../crypto/crypto_manager.dart';
import 'dart:convert';

class MessageApi {
  final _client = ApiClient.instance;

  /// Sends the PGP Armored String directly to the backend
  Future<void> sendMessage({
  required String recipientUserId,
  required String encryptedMessage,
  String? senderId,
}) async {
  await _client.post('/messages/send', data: {
    'recipient': recipientUserId,
    'ciphertext': encryptedMessage,
    'senderId': senderId ?? CryptoManager.instance.getUserId() ?? 'anonymous',
  });
}

  /// Returns a list of ChatMessage objects
  Future<List<ChatMessage>> receiveMessages(String userId) async {
    try {
      print('🔍 Fetching messages for user: $userId');
      final response = await _client.get('/messages/receive/$userId');
      
      print('📦 Response status: ${response.statusCode}');
      print('📦 Response data type: ${response.data.runtimeType}');
      
      // Get the raw data
      dynamic rawData = response.data;
      
      // If it's a string, parse it manually
      if (rawData is String) {
        print('⚠️ Response is a String, parsing manually...');
        rawData = jsonDecode(rawData);
      }
      
      print('📦 Parsed data type: ${rawData.runtimeType}');
      
      if (rawData == null) {
        print('⚠️ Response data is null');
        return [];
      }

      if (rawData is! List) {
        print('⚠️ Response data is not a List: ${rawData.runtimeType}');
        print('⚠️ Actual data: $rawData');
        return [];
      }

      final List<dynamic> messageList = rawData as List;
      print('📦 Processing ${messageList.length} messages');

      if (messageList.isEmpty) {
        print('ℹ️ No messages to process');
        return [];
      }

      final messages = <ChatMessage>[];
      
      for (var i = 0; i < messageList.length; i++) {
        try {
          var msgData = messageList[i];
          print('\n📦 ===== Message $i =====');
          print('📦 Type: ${msgData.runtimeType}');
          
          // If it's a string, parse it
          if (msgData is String) {
            print('⚠️ Message is a String, parsing...');
            msgData = jsonDecode(msgData);
          }
          
          // Convert to proper Map type
          Map<String, dynamic> messageMap;
          
          if (msgData is Map<String, dynamic>) {
            messageMap = msgData;
          } else if (msgData is Map) {
            print('⚠️ Converting Map to Map<String, dynamic>');
            messageMap = Map<String, dynamic>.from(msgData);
          } else {
            print('❌ Invalid message type, skipping');
            continue;
          }
          
          // Debug each field
          print('📦 Message fields:');
          messageMap.forEach((key, value) {
            print('  $key: (${value.runtimeType}) $value');
          });
          
          // Parse the message
          final message = ChatMessage.fromJson(messageMap);
          messages.add(message);
          print('✅ Parsed successfully');
          
        } catch (e, stackTrace) {
          print('❌ Failed to parse message $i: $e');
          print('Stack: $stackTrace');
        }
      }

      print('\n✅ Successfully processed ${messages.length}/${messageList.length} messages for $userId');
      return messages;
      
    } catch (e, stackTrace) {
      print('❌ Parsing error: $e');
      print('❌ Stack trace: $stackTrace');
      return [];
    }
  }

  /// Tells the backend to delete messages between these two users
  Future<void> clearConversation(String userId, String otherUserId) async {
    try {
      await _client.delete(
        '/messages/clear?userId=$userId&otherUserId=$otherUserId'
      );
      print('✅ Server-side deletion requested');
    } catch (e) {
      print('❌ Failed to clear messages: $e');
      rethrow;
    }
  }
}