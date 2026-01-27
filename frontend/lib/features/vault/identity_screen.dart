import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/auth_state.dart';
import '../../crypto/crypto_manager.dart';
import '../../core/auth/auth_provider.dart'; // Adjust the path based on your folders
class IdentityScreen extends ConsumerWidget {
  const IdentityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          child: const Text('Generate Identity Keys'),
          onPressed: () async {
            // 1. Create a unique internal identifier
            final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
            final anonymousEmail = 'user_$timestamp@vaultchat.local';
            
            // 2. Pass the required arguments to the manager
            await CryptoManager.instance.generateIdentityKeys(
              userId: 'VaultUser_$timestamp', // Optional
              email: anonymousEmail,          // Required
              passphrase: 'permanent_vault_lock', // Required
            );

            // 3. Update the auth state
            // Note: Check if your provider is 'authStateProvider' or 'authProvider' 
            // based on your previous files.
            ref.read(authProvider.notifier).initialize(); 
          },
        ),
      ),
    );
  }
}
