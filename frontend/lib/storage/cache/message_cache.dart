import 'package:hive_flutter/hive_flutter.dart';
import '../../features/chat/message_model.dart';

class MessageCache {
  static const String _boxName = 'messages';
  static Box<Map>? _box;

  static Future<void> initialize() async {
    _box = await Hive.openBox<Map>(_boxName);
  }

  static Future<void> saveMessage(ChatMessage message) async {
    if (_box == null) await initialize();
    
    final key = '${message.senderId}_${message.recipientId}_${message.id}';
    await _box!.put(key, message.toJson());
  }

  static Future<List<ChatMessage>> getConversation(String userId1, String userId2) async {
    if (_box == null) await initialize();
    
    final messages = <ChatMessage>[];
    
    for (var entry in _box!.toMap().entries) {
      try {
        final data = Map<String, dynamic>.from(entry.value as Map);
        final message = ChatMessage.fromJson(data);
        
        // Include messages in both directions
        if ((message.senderId == userId1 && message.recipientId == userId2) ||
            (message.senderId == userId2 && message.recipientId == userId1)) {
          
          // Check if message should be burned
          if (!message.shouldBurn) {
            messages.add(message);
          } else {
            // Delete burned messages
            await _box!.delete(entry.key);
          }
        }
      } catch (e) {
        print('Error parsing message: $e');
      }
    }
    
    messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return messages;
  }

  static Future<void> clearConversation(String userId1, String userId2) async {
    if (_box == null) await initialize();
    
    final keysToDelete = <dynamic>[];
    
    for (var entry in _box!.toMap().entries) {
      try {
        final data = Map<String, dynamic>.from(entry.value as Map);
        final message = ChatMessage.fromJson(data);
        
        if ((message.senderId == userId1 && message.recipientId == userId2) ||
            (message.senderId == userId2 && message.recipientId == userId1)) {
          keysToDelete.add(entry.key);
        }
      } catch (e) {
        print('Error checking message: $e');
      }
    }
    
    for (var key in keysToDelete) {
      await _box!.delete(key);
    }
  }

  static Future<void> clearAll() async {
    if (_box == null) await initialize();
    await _box!.clear();
  }
}