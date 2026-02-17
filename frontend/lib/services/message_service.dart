import 'dart:convert';
import '../network/http/message_api.dart';
import '../network/http/user_api.dart';
import '../crypto/crypto_manager.dart';
import '../features/chat/message_model.dart';
import 'steganography_service.dart';
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
    final myUserId = _crypto.getUserId()!;
    final recipientPublicKey = await _userApi.getUserPublicKey(recipientUserId);

    final payload = {
      '_vault_payload': true,
      'is_protocol': messageText.startsWith('PROTOCOL_'),
      'id': mediaMessage?.id ?? 'msg_${DateTime.now().millisecondsSinceEpoch}',
      'type': mediaMessage?.type.name ?? MessageType.text.name,
      'text': (mediaMessage != null && mediaMessage.text.isNotEmpty) ? mediaMessage.text : messageText,
      'fileData': mediaMessage?.fileData,
      'fileName': mediaMessage?.fileName,
      'mimeType': mediaMessage?.mimeType,
      'fileSize': mediaMessage?.fileSize,
      'senderId': myUserId,
      'recipientId': recipientUserId,
      'timestamp': (mediaMessage?.timestamp ?? DateTime.now()).toIso8601String(),
      'burnAfterSeconds': burnAfterSeconds ?? mediaMessage?.burnAfterSeconds,
    };
    
    // EVERY message is now encrypted, even protocol signals
    final finalContent = await _crypto.encrypt(jsonEncode(payload), recipientPublicKey);

    await _messageApi.sendMessage(
      recipientUserId: recipientUserId,
      encryptedMessage: finalContent,
      senderId: myUserId,
    );
  }

  Future<List<ChatMessage>> receiveMessages(String passphrase) async {
  final userId = _crypto.getUserId();
  if (userId == null) throw StateError('User not initialized');

  try {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final signature = await _crypto.sign('$userId|$timestamp');
    
    final received = await _messageApi.receiveMessages(
      userId: userId,
      signature: signature,
      timestamp: timestamp,
    );
    
    final results = <ChatMessage>[];
    final pass = passphrase.isNotEmpty ? passphrase : _crypto.getPassphrase();

    for (final msg in received) {
      debugPrint('📥 Received message: id=${msg.id}, hasText=${msg.text.isNotEmpty}');
      
      if (msg.text.isEmpty) {
        debugPrint('⚠️ Message has empty text, skipping: ${msg.id}');
        continue;
      }

      try {
        final decrypted = await _decryptMessage(msg.text, pass);
        debugPrint('🔓 Decrypted successfully');
        
        final processed = _processDecrypted(decrypted, msg);
        debugPrint('✅ Processed message: id=${processed.id}, text="${processed.text.length > 20 ? processed.text.substring(0,20)+'...' : processed.text}"');
        
        results.add(processed);
      } catch (e) {
        debugPrint('❌ Decrypt error ${msg.id}: $e');
        results.add(msg.copyWith(text: '🔒 [Decryption failed]', isSent: false));
      }
    }

    debugPrint('📦 Total messages processed: ${results.length}');
    return results;
  } catch (e) {
    debugPrint('❌ Receive error: $e');
    return [];
  }
}

  Future<String> _decryptMessage(String encryptedBody, String passphrase) async {
    if (encryptedBody.contains('-----BEGIN PGP MESSAGE-----')) {
      return await _crypto.decrypt(encryptedBody, passphrase);
    }
    return encryptedBody;
  }

  ChatMessage _processDecrypted(String decryptedText, ChatMessage original) {
    // 1. Try to parse as the new unified payload
    final parsed = _tryParsePayload(decryptedText, original);
    if (parsed != null) {
      return parsed;
    }

    // 2. Fallback for old/legacy messages or raw protocol signals
    return ChatMessage(
      id: original.id,
      text: decryptedText,
      senderId: original.senderId,
      recipientId: original.recipientId,
      timestamp: original.timestamp,
      isSent: false,
      isDelivered: original.isDelivered,
      isRead: original.isRead,
      type: MessageType.text,
      reactions: original.reactions,
    );
  }

  ChatMessage? _tryParsePayload(String text, ChatMessage original) {
  try {
    if (!text.trim().startsWith('{')) return null;
    
    final decoded = jsonDecode(text);
    if (decoded is! Map<String, dynamic>) return null;
    
    // Support both old '_media' flag and new '_vault_payload' flag
    if (decoded['_vault_payload'] != true && decoded['_media'] != true) return null;

    final typeStr = decoded['type']?.toString() ?? 'text';
    final type = MessageType.values.firstWhere(
      (e) => e.name == typeStr,
      orElse: () => MessageType.text,
    );

    int? toInt(dynamic v) => v == null ? null : (v is int ? v : int.tryParse(v.toString()));
    DateTime? toDate(dynamic v) => v == null ? null : DateTime.tryParse(v.toString());

    final fileData = decoded['fileData']?.toString();
    String decodedText = decoded['text']?.toString() ?? '';

    // STEGANOGRAPHY: Auto-decode ghost messages in images
    if (type == MessageType.image && fileData != null) {
      try {
        final bytes = base64Decode(fileData);
        final hidden = SteganographyService.decode(bytes);
        if (hidden.isNotEmpty) {
          decodedText = hidden; // The hidden text IS the message
          debugPrint('👻 Ghost Mode: Secret message extracted from image');
        }
      } catch (e) {
        debugPrint('⚠️ Steganography decode failed: $e');
      }
    }

    return ChatMessage(
      id: decoded['id']?.toString() ?? original.id,
      text: decodedText,
      senderId: decoded['senderId']?.toString() ?? original.senderId,
      recipientId: decoded['recipientId']?.toString() ?? original.recipientId,
      timestamp: toDate(decoded['timestamp']) ?? original.timestamp,
      isSent: false,
      type: type,
      fileData: fileData,
      fileName: decoded['fileName']?.toString(),
      mimeType: decoded['mimeType']?.toString(),
      fileSize: toInt(decoded['fileSize']),
      burnAfterSeconds: toInt(decoded['burnAfterSeconds']),
    );
  } catch (e) {
    debugPrint('Payload parse failed: $e');
    return null;
  }
}

  Future<void> registerCurrentUser() async {
    final userId = _crypto.getUserId();
    final publicKey = _crypto.getPublicKeyPem();
    if (userId != null && publicKey.isNotEmpty) {
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final signature = await _crypto.sign('$userId|$timestamp');
      
      await _userApi.registerUser(
        userId: userId,
        publicKeyPem: publicKey,
        signature: signature,
        timestamp: timestamp,
      );
    }
  }

  Future<void> clearChat(String otherUserId) async {
    final myId = _crypto.getUserId();
    if (myId == null) return;
    await _messageApi.clearConversation(myId, otherUserId);
  }
}
