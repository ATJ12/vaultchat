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
    this.reactions = const {},
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
      'reactions': reactions,
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    // Helper for safe String conversion
    String safeString(dynamic value, {String fallback = ""}) {
      if (value == null) return fallback;
      // Handle all types that might come from JSON
      if (value is String) return value;
      if (value is int) return value.toString();
      if (value is double) return value.toString();
      if (value is bool) return value.toString();
      return value.toString();
    }

    // Helper for safe Boolean conversion
    bool safeBool(dynamic value) {
      if (value == null) return false;
      if (value is bool) return value;
      if (value is int) return value == 1;
      if (value is String) {
        final lower = value.toLowerCase();
        return lower == 'true' || lower == '1';
      }
      return false;
    }

    // Helper for safe int conversion
    int? safeInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value);
      return null;
    }

    try {
      // Extract and validate id
      final rawId = json['id'];
      final id = safeString(rawId).isEmpty 
          ? "temp_${DateTime.now().millisecondsSinceEpoch}" 
          : safeString(rawId);
      
      // Extract text - backend sends 'ciphertext', frontend uses 'text'
      final rawText = json['text'] ?? json['ciphertext'];
      final text = safeString(rawText, fallback: "");
      
      // Extract sender and recipient
      final senderId = safeString(json['senderId'], fallback: "anonymous");
      final recipientId = safeString(json['recipientId'], fallback: "unknown");
      
      // Parse timestamp
      final timestamp = json['timestamp'] != null 
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now();
      
      // Parse boolean flags
      final isSent = safeBool(json['isSent']);
      final isDelivered = safeBool(json['isDelivered']);
      final isRead = safeBool(json['isRead']);
      
      // Parse optional integers
      final burnAfterSeconds = safeInt(json['burnAfterSeconds']);
      final fileSize = safeInt(json['fileSize']);
      
      // Parse message type
      final typeString = json['type']?.toString() ?? 'text';
      final type = MessageType.values.firstWhere(
        (e) => e.name == typeString,
        orElse: () => MessageType.text,
      );
      
      // Parse optional file fields
      final fileData = json['fileData'] != null ? safeString(json['fileData']) : null;
      final fileName = json['fileName'] != null ? safeString(json['fileName']) : null;
      final mimeType = json['mimeType'] != null ? safeString(json['mimeType']) : null;
      
      // Parse reactions
      final reactions = json['reactions'] != null 
          ? Map<String, String>.from(json['reactions'] as Map) 
          : const <String, String>{};

      return ChatMessage(
        id: id,
        text: text,
        senderId: senderId,
        recipientId: recipientId,
        timestamp: timestamp,
        isSent: isSent,
        isDelivered: isDelivered,
        isRead: isRead,
        burnAfterSeconds: burnAfterSeconds,
        type: type,
        fileData: fileData,
        fileName: fileName,
        mimeType: mimeType,
        fileSize: fileSize,
        reactions: reactions,
      );
    } catch (e, stackTrace) {
      // Log the error with full details
      print('❌ ChatMessage.fromJson failed: $e');
      print('❌ JSON data: $json');
      print('❌ Stack trace: $stackTrace');
      
      // Return a safe error message
      return ChatMessage(
        id: "error_${DateTime.now().millisecondsSinceEpoch}",
        text: "⚠️ Failed to parse message",
        senderId: "system",
        recipientId: "user",
        timestamp: DateTime.now(),
      );
    }
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