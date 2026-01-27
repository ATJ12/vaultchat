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

// --- UI SCREENS ---

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('VaultChat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: const Center(child: Text('Your Secure Conversations')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/chat/new_user'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _isGenerating = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.security, size: 100, color: Colors.blue),
              const SizedBox(height: 24),
              const Text(
                'Welcome to VaultChat', 
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Generate your unique OpenPGP keys to begin chatting. No personal data required.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 40),
              _isGenerating 
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    ),
                    onPressed: () async {
                      setState(() => _isGenerating = true);
                      try {
                        // Generate an anonymous ID based on time
                        final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
                        
                        // Satisfy OpenPGP requirements with "Ghost" data
                        await CryptoManager.instance.generateIdentityKeys(
                          email: 'vault_$timestamp@vaultchat.local', 
                          passphrase: 'permanent_local_vault_key', // Hidden from user
                        );

                        if (context.mounted) context.go('/');
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Generation Failed: $e')),
                          );
                        }
                      } finally {
                        if (mounted) setState(() => _isGenerating = false);
                      }
                    },
                    child: const Text('Generate Keys & Start'),
                  ),
            ],
          ),
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
            subtitle: const Text('Manage keys and encryption'),
            onTap: () => context.push('/settings/privacy'),
          ),
        ],
      ),
    );
  }
}