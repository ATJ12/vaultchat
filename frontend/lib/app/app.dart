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
      home: _buildHome(context, authState, ref),
    );
  }

  Widget _buildHome(BuildContext context, AuthState state, WidgetRef ref) {
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
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 64,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    state.errorMessage ?? 'Unknown error',
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
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
      body: activeRoom == null
          ? _EmptyState(userId: userId)
          : _ActiveRoomCard(
              activeRoom: activeRoom,
              onOpenChat: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(userId: activeRoom),
                  ),
                );
              },
              onLeaveRoom: () async {
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
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(ctx).colorScheme.error,
                        ),
                        child: const Text('Leave'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await ref.read(activeRoomProvider.notifier).setActiveRoom(null);
                }
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push<String>(
            context,
            MaterialPageRoute(
              builder: (context) => const RoomEntryScreen(),
            ),
          );
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

class _EmptyState extends StatelessWidget {
  final String userId;

  const _EmptyState({required this.userId});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.chat_bubble_outline_rounded,
                size: 64,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No active chat',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the button below to start a secure conversation',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.fingerprint, size: 18, color: scheme.primary),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      userId,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
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

class _ActiveRoomCard extends StatelessWidget {
  final String activeRoom;
  final VoidCallback onOpenChat;
  final VoidCallback onLeaveRoom;

  const _ActiveRoomCard({
    required this.activeRoom,
    required this.onOpenChat,
    required this.onLeaveRoom,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          elevation: 0,
          color: scheme.surfaceContainerHighest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.lock_rounded, size: 48, color: scheme.onPrimaryContainer),
                ),
                const SizedBox(height: 20),
                Text(
                  'Active room',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  activeRoom,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: onOpenChat,
                  icon: const Icon(Icons.chat_rounded),
                  label: const Text('Open Chat'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: onLeaveRoom,
                  icon: Icon(Icons.exit_to_app, size: 18, color: scheme.error),
                  label: Text('Leave room', style: TextStyle(color: scheme.error)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}