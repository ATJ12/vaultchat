import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../crypto/crypto_manager.dart';
import '../../storage/secure/secure_storage.dart';
import '../../storage/cache/message_cache.dart';
import '../../core/auth/auth_provider.dart';

class PrivacySettingsScreen extends ConsumerWidget {
  const PrivacySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy & Security'),
      ),
      body: ListView(
        children: [
          const _SectionHeader(title: 'Identity'),
          _IdentityInfoTile(),
          const Divider(),
          
          const _SectionHeader(title: 'Encryption'),
          const _InfoTile(
            icon: Icons.lock,
            title: 'End-to-End Encryption',
            subtitle: 'All messages are encrypted with RSA-2048',
            trailing: Icon(Icons.check_circle, color: Colors.green),
          ),
          const _InfoTile(
            icon: Icons.key,
            title: 'Zero-Knowledge Architecture',
            subtitle: 'Server never sees your messages',
          ),
          const _InfoTile(
            icon: Icons.storage_rounded,
            title: 'Hardware-Grade Local Security',
            subtitle: 'Stretched via PBKDF2 (100,000 iterations)',
            trailing: Icon(Icons.verified_user, color: Colors.blueAccent),
          ),
          
          
          const Divider(),
          const _SectionHeader(title: 'Danger Zone'),
          
          _DeleteDataTile(ref: ref),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _IdentityInfoTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final userId = CryptoManager.instance.getUserId() ?? 'Unknown';
    final publicKey = CryptoManager.instance.getPublicKeyPem();

    return ListTile(
      leading: const Icon(Icons.person),
      title: const Text('User ID'),
      subtitle: Text(userId),
      trailing: IconButton(
        icon: const Icon(Icons.copy),
        onPressed: () {
          Clipboard.setData(ClipboardData(text: userId));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User ID copied to clipboard')),
          );
        },
      ),
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Your Public Key'),
            content: SingleChildScrollView(
              child: SelectableText(
                publicKey,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: publicKey));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Public key copied')),
                  );
                },
                child: const Text('Copy'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;

  const _InfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: trailing,
    );
  }
}


class _DeleteDataTile extends StatelessWidget {
  final WidgetRef ref;

  const _DeleteDataTile({required this.ref});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.delete_forever, color: Colors.red),
      title: const Text('Delete All Data'),
      subtitle: const Text('Remove all keys, messages, and account'),
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Everything?'),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This will permanently delete:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text('✗ Your encryption keys'),
                Text('✗ All message history'),
                Text('✗ Your user identity'),
                Text('✗ All local data'),
                SizedBox(height: 16),
                Text(
                  'This action CANNOT be undone!',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  
                  // Clear everything
                  await SecureStorage.clearAll();
                  await MessageCache.clearAll();
                  
                  // Update auth state
                  ref.read(authProvider.notifier).deleteIdentity();
                  
                  if (context.mounted) {
                    // Go back to onboarding
                    Navigator.of(context).popUntil((route) => route.isFirst);
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('All data deleted'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                child: const Text('Delete Everything'),
              ),
            ],
          ),
        );
      },
    );
  }
}