import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/auth/auth_provider.dart';
import '../core/auth/auth_state.dart';
import '../features/auth/identity_screen.dart';
import '../features/chat/chat_screen.dart';
import '../features/chat/room_entry_screen.dart';
import '../features/common/loading_screen.dart';
import '../features/settings/privacy_settings.dart';
import '../ui/theme.dart';
import '../storage/cache/message_cache.dart';
import '../crypto/crypto_manager.dart';
import '../services/message_service.dart';

// Provider to track current active room
final activeRoomProvider = StateNotifierProvider<ActiveRoomNotifier, String?>((ref) {
  return ActiveRoomNotifier();
});

class ActiveRoomNotifier extends StateNotifier<String?> {
  ActiveRoomNotifier() : super(null);

  Future<void> setActiveRoom(String? userId) async {
    final previousRoom = state;
    
    // If there was a previous room and it's different from the new one
    if (previousRoom != null && previousRoom != userId) {
      await _deletePreviousRoom(previousRoom);
    }
    
    state = userId;
  }

  Future<void> _deletePreviousRoom(String otherUserId) async {
    final myId = CryptoManager.instance.getUserId();
    if (myId == null) return;

    try {
      // Send deletion signal to peer
      final messageService = MessageService();
      await messageService.sendMessage(
        recipientUserId: otherUserId,
        messageText: "PROTOCOL_DELETE_CONVERSATION_SYNC",
      );

      // Clear local cache
      await MessageCache.clearConversation(myId, otherUserId);

      // Clear server messages after delay
      Future.delayed(const Duration(seconds: 6), () {
        messageService.clearChat(otherUserId);
      });

      debugPrint('Previous room with $otherUserId deleted');
    } catch (e) {
      debugPrint('Error deleting previous room: $e');
    }
  }

  void clearActiveRoom() {
    state = null;
  }
}

class VaultChatApp extends ConsumerWidget {
  const VaultChatApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'VaultChat',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      home: _buildHome(authState, ref),
    );
  }

  Widget _buildHome(AuthState state, WidgetRef ref) {
    switch (state.status) {
      case AuthStatus.initializing:
        return const LoadingScreen(
          message: 'Initializing secure vault...',
        );

      case AuthStatus.noIdentity:
        return const IdentityScreen();

      case AuthStatus.ready:
        return ChatListScreen(userId: state.userId!);

      case AuthStatus.error:
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  state.errorMessage ?? 'Unknown error',
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
    }
  }
}

class ChatListScreen extends ConsumerWidget {
  final String userId;

  const ChatListScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeRoom = ref.watch(activeRoomProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('VaultChat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PrivacySettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (activeRoom == null) ...[
              const Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'No active room',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Text(
                'Your ID: $userId',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 32),
              const Text(
                'Tap + to create a secure room',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ] else ...[
              const Icon(Icons.lock, size: 64, color: Colors.green),
              const SizedBox(height: 16),
              const Text(
                'Active Room',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'With: $activeRoom',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(userId: activeRoom),
                    ),
                  );
                },
                icon: const Icon(Icons.chat),
                label: const Text('Open Chat'),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () async {
                  // Show confirmation dialog
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Leave Room'),
                      content: const Text(
                        'Are you sure you want to leave this room? All messages will be deleted.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: TextButton.styleFrom(foregroundColor: Colors.red),
                          child: const Text('Leave'),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    await ref.read(activeRoomProvider.notifier).setActiveRoom(null);
                  }
                },
                icon: const Icon(Icons.exit_to_app, color: Colors.red),
                label: const Text('Leave Room', style: TextStyle(color: Colors.red)),
              ),
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // Navigate to room entry screen
          final result = await Navigator.push<String>(
            context,
            MaterialPageRoute(
              builder: (context) => const RoomEntryScreen(),
            ),
          );

          // If a room was created/joined, set it as active
          if (result != null && result.isNotEmpty) {
            await ref.read(activeRoomProvider.notifier).setActiveRoom(result);
          }
        },
        icon: const Icon(Icons.add),
        label: Text(activeRoom == null ? 'New Chat' : 'Switch Room'),
      ),
    );
  }
}