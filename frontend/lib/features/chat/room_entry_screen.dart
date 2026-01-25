import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../crypto/crypto_manager.dart';
import '../../storage/cache/room_storage.dart';
import '../../network/http/room_api.dart';
import 'room_model.dart';
import 'chat_screen.dart';
import '../../services/message_service.dart';
import '../../storage/cache/message_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class RoomEntryScreen extends StatefulWidget {
  const RoomEntryScreen({super.key});

  @override
  State<RoomEntryScreen> createState() => _RoomEntryScreenState();
}

class _RoomEntryScreenState extends State<RoomEntryScreen> {
  final _recipientController = TextEditingController();
  final _codeController = TextEditingController();
  final _roomApi = RoomApi();
  bool _isCreating = false;

  @override
  void dispose() {
    _recipientController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  /// Get user's active room from storage
  Future<ChatRoom?> _getActiveRoom() async {
    final myUserId = CryptoManager.instance.getUserId()!;
    final prefs = await SharedPreferences.getInstance();
    final roomJson = prefs.getString('active_room_$myUserId');
    if (roomJson == null) return null;
    return ChatRoom.fromJson(jsonDecode(roomJson));
  }

  /// Save active room to storage
  Future<void> _saveActiveRoom(ChatRoom room) async {
    final myUserId = CryptoManager.instance.getUserId()!;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_room_$myUserId', jsonEncode(room.toJson()));
  }

  /// Delete active room from storage
  Future<void> _deleteActiveRoom() async {
    final myUserId = CryptoManager.instance.getUserId()!;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_room_$myUserId');
  }

  /// Delete previous room before creating new one
  Future<void> _deletePreviousRoom() async {
    final myUserId = CryptoManager.instance.getUserId()!;
    
    // Get active room
    final previousRoom = await _getActiveRoom();
    if (previousRoom == null) {
      debugPrint('No previous room to delete');
      return;
    }

    try {
      final otherUserId = previousRoom.getOtherUser(myUserId);
      
      debugPrint('🗑️ Deleting previous room: ${previousRoom.roomCode}');
      
      // 1. Send "USER_LEFT" notification to other user
      final messageService = MessageService();
      await messageService.sendMessage(
        recipientUserId: otherUserId,
        messageText: "PROTOCOL_USER_LEFT_ROOM",
      );
      
      debugPrint('📤 Sent USER_LEFT signal to $otherUserId');
      
      // 2. Clear local messages
      await MessageCache.clearConversation(myUserId, otherUserId);
      
      // 3. Delete local room data
      await _deleteActiveRoom();
      
      // Wait a bit for the signal to be sent
      await Future.delayed(const Duration(milliseconds: 500));
      
      debugPrint('✅ Previous room deleted successfully');
    } catch (e) {
      debugPrint('❌ Error deleting previous room: $e');
    }
  }

  Future<void> _createRoom() async {
    final recipient = _recipientController.text.trim();
    if (recipient.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter recipient user ID')),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      final myUserId = CryptoManager.instance.getUserId()!;
      
      // DELETE PREVIOUS ROOM FIRST
      await _deletePreviousRoom();
      
      // Create new room locally
      final room = await RoomStorage.createRoom(
        myUserId: myUserId,
        otherUserId: recipient,
      );

      // Send to backend (backend will also delete old room)
      await _roomApi.createRoom(
        user1Id: myUserId,
        user2Id: recipient,
        roomCode: room.roomCode,
      );

      // Save as active room
      await _saveActiveRoom(room);

      if (mounted) {
        setState(() => _isCreating = false);
        
        // Show room code dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('🔐 Room Created!'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Share this code with your contact:',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue, width: 2),
                  ),
                  child: SelectableText(
                    room.roomCode,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: room.roomCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Code copied!')),
                    );
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy Code'),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context, recipient); // Return to chat list
                  
                  // Navigate to chat
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(userId: recipient),
                    ),
                  );
                },
                child: const Text('Enter Chat'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCreating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _joinRoom() async {
    final recipient = _recipientController.text.trim();
    final code = _codeController.text.trim().toUpperCase();

    if (recipient.isEmpty || code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both user ID and code')),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      final myUserId = CryptoManager.instance.getUserId()!;
      
      // DELETE PREVIOUS ROOM FIRST
      await _deletePreviousRoom();
      
      // Verify with backend
      final success = await _roomApi.joinRoom(
        user1Id: recipient,
        user2Id: myUserId,
        roomCode: code,
      );

      if (mounted) {
        setState(() => _isCreating = false);

        if (success) {
          // Save locally
          final room = await RoomStorage.createRoom(
            myUserId: myUserId,
            otherUserId: recipient,
          );
          
          // Save as active room
          await _saveActiveRoom(room);
          
          Navigator.pop(context, recipient);
          
          // Navigate to chat
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(userId: recipient),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Room not found or has been deleted'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCreating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Start Secure Chat'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.lock, size: 80, color: Colors.blue),
            const SizedBox(height: 24),

            const Text(
              'Secure Room',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Create a room or join with a code',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),

            TextField(
              controller: _recipientController,
              decoration: const InputDecoration(
                labelText: 'Recipient User ID',
                hintText: 'Enter their user ID',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            ElevatedButton.icon(
              onPressed: _isCreating ? null : _createRoom,
              icon: _isCreating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
              label: const Text('Create Room & Get Code'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Colors.blue,
              ),
            ),

            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 32),

            const Text(
              'Already have a code?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _codeController,
              decoration: const InputDecoration(
                labelText: 'Room Code',
                hintText: 'Enter 6-digit code',
                prefixIcon: Icon(Icons.vpn_key),
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
            ),
            const SizedBox(height: 16),

            ElevatedButton.icon(
              onPressed: _isCreating ? null : _joinRoom,
              icon: const Icon(Icons.login),
              label: const Text('Join Room'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Colors.green,
              ),
            ),

            const SizedBox(height: 32),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange),
                      SizedBox(width: 8),
                      Text(
                        'How it works',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text('1. Create a room to get a unique code'),
                  Text('2. Share the code with your contact'),
                  Text('3. Both enter the same code to chat'),
                  Text('4. Messages are end-to-end encrypted'),
                  SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('⚠️ ', style: TextStyle(fontSize: 16)),
                      Expanded(
                        child: Text(
                          'Creating a new room will:\n• Delete your previous room from server\n• Notify the other person you left\n• Make old room codes invalid',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}