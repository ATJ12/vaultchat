import 'package:equatable/equatable.dart';

class ChatRoom extends Equatable {
  final String roomId;
  final String roomCode;
  final String user1Id;
  final String user2Id;
  final DateTime createdAt;

  const ChatRoom({
    required this.roomId,
    required this.roomCode,
    required this.user1Id,
    required this.user2Id,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'roomId': roomId,
      'roomCode': roomCode,
      'user1Id': user1Id,
      'user2Id': user2Id,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ChatRoom.fromJson(Map<String, dynamic> json) {
    return ChatRoom(
      roomId: json['roomId'] as String,
      roomCode: json['roomCode'] as String,
      user1Id: json['user1Id'] as String,
      user2Id: json['user2Id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  bool hasUser(String userId) {
    return user1Id == userId || user2Id == userId;
  }

  String getOtherUser(String myUserId) {
    return user1Id == myUserId ? user2Id : user1Id;
  }

  @override
  List<Object?> get props => [roomId, roomCode, user1Id, user2Id, createdAt];
}