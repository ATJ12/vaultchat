import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_provider.dart';

class IdentityScreen extends ConsumerStatefulWidget {
  const IdentityScreen({super.key});

  @override
  ConsumerState<IdentityScreen> createState() => _IdentityScreenState();
}

class _IdentityScreenState extends ConsumerState<IdentityScreen> {
  final _userIdController = TextEditingController();
  final _passphraseController = TextEditingController();
  bool _isGenerating = false;
  bool _obscurePassphrase = true;

  @override
  void dispose() {
    _userIdController.dispose();
    _passphraseController.dispose();
    super.dispose();
  }

  Future<void> _generateIdentity() async {
    if (_isGenerating) return;
    
    setState(() => _isGenerating = true);

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        content: Container(
          width: double.maxFinite,
          constraints: const BoxConstraints(maxWidth: 300),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              const Text(
                'Generating Secure Identity',
                style: TextStyle(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                kIsWeb 
                  ? 'The browser may freeze for up to 30s while performing encryption math.\nDo not close this tab.' 
                  : 'Generating RSA keys...',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final customUserId = _userIdController.text.trim();
      final passphrase = _passphraseController.text;

      if (passphrase.length < 8) {
        if (mounted) Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Passphrase must be at least 8 characters')),
        );
        setState(() => _isGenerating = false);
        return;
      }
      
      // Let the dialog render fully before the CPU heavy task
      await Future.delayed(const Duration(milliseconds: 800));
      
      await ref.read(authProvider.notifier).generateIdentity(
            customUserId: customUserId.isEmpty ? null : customUserId,
            passphrase: passphrase,
          );
      
      if (mounted) Navigator.of(context).pop(); // Close dialog
      
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'), 
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 10),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.enhanced_encryption_rounded, 
                    size: 80, 
                    color: Theme.of(context).colorScheme.primary
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'VaultChat Identity',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Create your unique cryptographic identity to start messaging.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 40),
                  TextField(
                    controller: _userIdController,
                    decoration: InputDecoration(
                      labelText: 'Choose a Username',
                      hintText: 'e.g., malik_vault',
                      prefixIcon: const Icon(Icons.alternate_email),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passphraseController,
                    obscureText: _obscurePassphrase,
                    decoration: InputDecoration(
                      labelText: 'Vault Passphrase',
                      hintText: 'Min. 8 characters',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassphrase ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _obscurePassphrase = !_obscurePassphrase),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      helperText: 'Required for local data encryption.',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '⚠️ Loss of this passphrase means loss of all chat history.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isGenerating ? null : _generateIdentity,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isGenerating 
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Generate & Join Vault', style: TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(height: 40),
                  const _InfoTile(
                    icon: Icons.security,
                    title: 'End-to-End Encrypted',
                    desc: 'Keys are generated and stored only on your device.',
                  ),
                  const _InfoTile(
                    icon: Icons.storage_rounded,
                    title: 'Hardware-Grade Security',
                    desc: 'Local database is secured with PBKDF2 (100k rounds).',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  const _InfoTile({required this.icon, required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}