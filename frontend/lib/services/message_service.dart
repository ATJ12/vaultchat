import 'dart:convert';
import 'dart:typed_data';
import '../network/http/message_api.dart';
import '../network/http/user_api.dart';
import '../crypto/crypto_manager.dart';
import '../features/chat/message_model.dart';

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
    final recipientPublicKey = await _userApi.getUserPublicKey(recipientUserId);
    
    final message = mediaMessage ?? ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: messageText,
      senderId: _crypto.getUserId()!,
      recipientId: recipientUserId,
      timestamp: DateTime.now(),
      isSent: false,
      burnAfterSeconds: burnAfterSeconds,
    );
    
    final messageJson = json.encode(message.toJson());
    final plaintext = utf8.encode(messageJson);
    
    final ciphertext = await _crypto.encrypt(
      Uint8List.fromList(plaintext),
      recipientPublicKey,
    );
    
    await _messageApi.sendMessage(
      recipientUserId: recipientUserId,
      encryptedMessage: ciphertext,
    );
  }

  Future<List<ChatMessage>> receiveMessages() async {
    final userId = _crypto.getUserId();
    if (userId == null) throw StateError('User not initialized');
    
    final encryptedMessages = await _messageApi.receiveMessages(userId);
    final messages = <ChatMessage>[];

    for (var ciphertext in encryptedMessages) {
      try {
        final plaintext = await _crypto.decrypt(ciphertext);
        final messageJson = utf8.decode(plaintext);
        final messageData = json.decode(messageJson) as Map<String, dynamic>;
        messages.add(ChatMessage.fromJson(messageData));
      } catch (e) {
        print('❌ Decryption failed: $e');
      }
    }
    return messages;
  }

  // NEW: Tells the server to delete the messages permanently
  Future<void> clearChat(String otherUserId) async {
    final myId = _crypto.getUserId();
    if (myId == null) return;
    try {
      // Logic: Tell the backend to delete messages between these two IDs
      await _messageApi.clearConversation(myId, otherUserId);
    } catch (e) {
      print('❌ Server clear failed: $e');
      rethrow;
    }
  }

  Future<void> registerCurrentUser() async {
    final userId = _crypto.getUserId();
    final publicKeyPem = _crypto.getPublicKeyPem();
    if (userId == null) throw StateError('User ID not set');
    await _userApi.registerUser(userId, publicKeyPem);
  }
}