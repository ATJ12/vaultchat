import 'dart:convert';
import '../network/http/message_api.dart';
import '../network/http/user_api.dart';
import '../crypto/crypto_manager.dart'; 
import '../features/chat/message_model.dart';
import 'package:flutter/foundation.dart';

class MessageService {
  final _messageApi = MessageApi();
  final _userApi = UserApi();
  final _crypto = CryptoManager.instance;

  Future<void> sendMessage({
    required String recipientUserId,
    required String messageText,
    int? burnAfterSeconds,
    ChatMessage? mediaMessage,
  }) async {
    try {
      // 1. Get recipient's public key
      final recipientPublicKey = await _userApi.getUserPublicKey(recipientUserId);
      
      // 2. Encrypt the text
      String finalContent;
      if (messageText.startsWith("PROTOCOL_")) {
        finalContent = messageText;
      } else {
        finalContent = await _crypto.encrypt(messageText, recipientPublicKey);
      }

      // 3. Prepare the object
      final message = mediaMessage?.copyWith(text: finalContent) ?? ChatMessage(
        id: "msg_${DateTime.now().millisecondsSinceEpoch}",
        text: finalContent,
        senderId: _crypto.getUserId()!,
        recipientId: recipientUserId,
        timestamp: DateTime.now(),
        isSent: true,
        burnAfterSeconds: burnAfterSeconds,
      );
      
      // 4. Send to API 
      await _messageApi.sendMessage(
        recipientUserId: recipientUserId, 
        encryptedMessage: message.text, 
        senderId: _crypto.getUserId() ?? 'anonymous',  // ✅ ADD this

      );
      
      debugPrint('✅ Message sent to $recipientUserId');
    } catch (e) {
      debugPrint('❌ Send Error: $e');
      rethrow;
    }
  }

  Future<List<ChatMessage>> receiveMessages(String passphrase) async {
    final userId = _crypto.getUserId();
    if (userId == null) throw StateError('User not initialized');
    
    try {
      // 1. Fetch the ChatMessage list from server (NOT raw dynamic anymore!)
      final List<ChatMessage> receivedMessages = await _messageApi.receiveMessages(userId);
      final messages = <ChatMessage>[];

      // 2. Process messages - decrypt the text field
      for (var message in receivedMessages) {
        try {
          // A. Get the ciphertext from the message object (not map!)
          String encryptedBody = message.text;
          if (encryptedBody.isEmpty) continue;

          // B. Decrypt if it's actually encrypted
          String decryptedText = encryptedBody;
          if (encryptedBody.contains('-----BEGIN PGP MESSAGE-----')) {
            decryptedText = await _crypto.decrypt(encryptedBody, passphrase);
          }

          // C. Create a new message with decrypted text
          messages.add(message.copyWith(
            text: decryptedText,
            isSent: false, // It's a received message
          ));
          
        } catch (e) {
          debugPrint('❌ Decryption error for message ${message.id}: $e');
          // Add the message anyway with encrypted text so user knows something came in
          messages.add(message.copyWith(
            text: '🔒 [Decryption failed]',
            isSent: false,
          ));
        }
      }
      
      debugPrint('📥 Successfully processed ${messages.length} messages for $userId');
      return messages;
    } catch (e) {
      debugPrint('❌ Global Receive Error: $e');
      return [];
    }
  }

  // --- Helper Methods ---

  Future<void> registerCurrentUser() async {
    final userId = _crypto.getUserId();
    final publicKey = _crypto.getPublicKeyPem();
    if (userId != null && publicKey.isNotEmpty) {
      await _userApi.registerUser(userId, publicKey);
    }
  }

  Future<void> clearChat(String otherUserId) async {
    final myId = _crypto.getUserId();
    if (myId == null) return;
    try {
      await _messageApi.clearConversation(myId, otherUserId);
    } catch (e) {
      debugPrint('❌ Failed to clear chat: $e');
      rethrow;
    }
  }
}