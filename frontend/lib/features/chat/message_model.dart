import 'package:equatable/equatable.dart';

enum MessageType {
  text,
  image,
  file,
  audio,
}

class ChatMessage extends Equatable {
  final String id;
  final String text;
  final String senderId;
  final String recipientId;
  final DateTime timestamp;
  final bool isSent;
  final bool isDelivered;
  final bool isRead;
  final int? burnAfterSeconds;
  final MessageType type;
  final String? fileData;
  final String? fileName;
  final String? mimeType;
  final int? fileSize;
  // CHANGED: Map to store userId: emoji (e.g., {"userA": "👍", "userB": "🔥"})
  final Map<String, String> reactions; 

  const ChatMessage({
    required this.id,
    required this.text,
    required this.senderId,
    required this.recipientId,
    required this.timestamp,
    this.isSent = false,
    this.isDelivered = false,
    this.isRead = false,
    this.burnAfterSeconds,
    this.type = MessageType.text,
    this.fileData,
    this.fileName,
    this.mimeType,
    this.fileSize,
    this.reactions = const {}, // Default to empty map
  });

  ChatMessage copyWith({
    String? id,
    String? text,
    String? senderId,
    String? recipientId,
    DateTime? timestamp,
    bool? isSent,
    bool? isDelivered,
    bool? isRead,
    int? burnAfterSeconds,
    MessageType? type,
    String? fileData,
    String? fileName,
    String? mimeType,
    int? fileSize,
    Map<String, String>? reactions,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      senderId: senderId ?? this.senderId,
      recipientId: recipientId ?? this.recipientId,
      timestamp: timestamp ?? this.timestamp,
      isSent: isSent ?? this.isSent,
      isDelivered: isDelivered ?? this.isDelivered,
      isRead: isRead ?? this.isRead,
      burnAfterSeconds: burnAfterSeconds ?? this.burnAfterSeconds,
      type: type ?? this.type,
      fileData: fileData ?? this.fileData,
      fileName: fileName ?? this.fileName,
      mimeType: mimeType ?? this.mimeType,
      fileSize: fileSize ?? this.fileSize,
      reactions: reactions ?? this.reactions,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'senderId': senderId,
      'recipientId': recipientId,
      'timestamp': timestamp.toIso8601String(),
      'isSent': isSent,
      'isDelivered': isDelivered,
      'isRead': isRead,
      'burnAfterSeconds': burnAfterSeconds,
      'type': type.name,
      'fileData': fileData,
      'fileName': fileName,
      'mimeType': mimeType,
      'fileSize': fileSize,
      'reactions': reactions, // Map is JSON compatible
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      text: json['text'] as String,
      senderId: json['senderId'] as String,
      recipientId: json['recipientId'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      isSent: json['isSent'] as bool? ?? false,
      isDelivered: json['isDelivered'] as bool? ?? false,
      isRead: json['isRead'] as bool? ?? false,
      burnAfterSeconds: json['burnAfterSeconds'] as int?,
      type: MessageType.values.firstWhere(
        (e) => e.name == (json['type'] as String? ?? 'text'),
        orElse: () => MessageType.text,
      ),
      fileData: json['fileData'] as String?,
      fileName: json['fileName'] as String?,
      mimeType: json['mimeType'] as String?,
      fileSize: json['fileSize'] as int?,
      // Safe casting of the map
      reactions: json['reactions'] != null 
          ? Map<String, String>.from(json['reactions'] as Map) 
          : {},
    );
  }

  bool get shouldBurn {
    if (burnAfterSeconds == null) return false;
    final elapsed = DateTime.now().difference(timestamp).inSeconds;
    return elapsed >= burnAfterSeconds!;
  }

  int get remainingSeconds {
    if (burnAfterSeconds == null) return 0;
    final elapsed = DateTime.now().difference(timestamp).inSeconds;
    return (burnAfterSeconds! - elapsed).clamp(0, burnAfterSeconds!);
  }

  @override
  List<Object?> get props => [
        id, text, senderId, recipientId, timestamp, isSent,
        isDelivered, isRead, burnAfterSeconds, type, 
        fileData, fileName, mimeType, fileSize, reactions,
      ];
}