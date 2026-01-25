import 'package:hive_flutter/hive_flutter.dart';
import '../../features/chat/room_model.dart';
import 'dart:math';

class RoomStorage {
  static const String _boxName = 'chat_rooms';
  static Box<Map>? _box;

  static Future<void> initialize() async {
    _box = await Hive.openBox<Map>(_boxName);
  }

  static String generateRoomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(6, (index) => chars[random.nextInt(chars.length)]).join();
  }

  static Future<ChatRoom> createRoom({
    required String myUserId,
    required String otherUserId,
  }) async {
    if (_box == null) await initialize();

    final roomCode = generateRoomCode();
    final roomId = '${myUserId}_${otherUserId}_${DateTime.now().millisecondsSinceEpoch}';

    final room = ChatRoom(
      roomId: roomId,
      roomCode: roomCode,
      user1Id: myUserId,
      user2Id: otherUserId,
      createdAt: DateTime.now(),
    );

    await _box!.put(roomId, room.toJson());
    return room;
  }

  static Future<ChatRoom?> joinRoom({
    required String myUserId,
    required String otherUserId,
    required String roomCode,
  }) async {
    if (_box == null) await initialize();

    // Find room with matching code
    for (var entry in _box!.toMap().entries) {
      try {
        final data = Map<String, dynamic>.from(entry.value as Map);
        final room = ChatRoom.fromJson(data);

        // Check if code matches
        if (room.roomCode.toUpperCase() == roomCode.toUpperCase()) {
          // Check if this room involves both users
          // Either: (user1=me, user2=other) OR (user1=other, user2=me)
          final hasMe = room.user1Id == myUserId || room.user2Id == myUserId;
          final hasOther = room.user1Id == otherUserId || room.user2Id == otherUserId;
          
          if (hasMe && hasOther) {
            print('✅ Room found! User1: ${room.user1Id}, User2: ${room.user2Id}');
            return room;
          }
        }
      } catch (e) {
        print('Error parsing room: $e');
      }
    }

    print('❌ No matching room found for code: $roomCode, users: $myUserId <-> $otherUserId');
    return null;
  }

  static Future<List<ChatRoom>> getMyRooms(String userId) async {
    if (_box == null) await initialize();

    final rooms = <ChatRoom>[];
    for (var entry in _box!.toMap().entries) {
      try {
        final data = Map<String, dynamic>.from(entry.value as Map);
        final room = ChatRoom.fromJson(data);

        if (room.hasUser(userId)) {
          rooms.add(room);
        }
      } catch (e) {
        print('Error parsing room: $e');
      }
    }

    rooms.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return rooms;
  }

  static Future<void> deleteRoom(String roomId) async {
    if (_box == null) await initialize();
    await _box!.delete(roomId);
  }

  static Future<void> clearAll() async {
    if (_box == null) await initialize();
    await _box!.clear();
  }
}