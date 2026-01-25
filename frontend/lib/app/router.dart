import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/chat/chat_screen.dart';
import '../features/settings/privacy_settings.dart';
import '../crypto/crypto_manager.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) async {
      // Check if user has identity keys
      final hasKeys = await CryptoManager.instance.hasIdentityKeys();
      
      final isOnboarding = state.matchedLocation == '/onboarding';
      
      if (!hasKeys && !isOnboarding) {
        return '/onboarding';
      }
      
      if (hasKeys && isOnboarding) {
        return '/';
      }
      
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const ChatListScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/chat/:userId',
        builder: (context, state) {
          final userId = state.pathParameters['userId']!;
          return ChatScreen(userId: userId);
        },
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/settings/privacy',
        builder: (context, state) => const PrivacySettingsScreen(),
      ),
    ],
  );
});

// Placeholder screens
class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('VaultChat')),
      body: const Center(child: Text('Chat List')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/chat/alice'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Welcome to VaultChat', 
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                await CryptoManager.instance.generateIdentityKeys();
                if (context.mounted) context.go('/');
              },
              child: const Text('Generate Keys & Start'),
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.privacy_tip),
            title: const Text('Privacy & Security'),
            onTap: () => context.push('/settings/privacy'),
          ),
        ],
      ),
    );
  }
}