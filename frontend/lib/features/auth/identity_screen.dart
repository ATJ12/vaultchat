import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_provider.dart';

class IdentityScreen extends ConsumerStatefulWidget {
  const IdentityScreen({super.key});

  @override
  ConsumerState<IdentityScreen> createState() => _IdentityScreenState();
}

class _IdentityScreenState extends ConsumerState<IdentityScreen> {
  final _userIdController = TextEditingController();
  bool _isGenerating = false;

  @override
  void dispose() {
    _userIdController.dispose();
    super.dispose();
  }

  Future<void> _generateIdentity() async {
    if (_isGenerating) return;
    
    setState(() => _isGenerating = true);

    // Show loading dialog
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Generating RSA-2048 keys...\nThis may take a moment.'),
            ],
          ),
        ),
      );
    }

    try {
      final customUserId = _userIdController.text.trim();
      
      // Run in separate isolate to prevent blocking UI
      await Future.delayed(const Duration(milliseconds: 100));
      
      await ref.read(authProvider.notifier).generateIdentity(
            customUserId: customUserId.isEmpty ? null : customUserId,
          );
      
      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate identity: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo/Icon
              Icon(
                Icons.lock_outline,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 32),

              // Title
              Text(
                'Welcome to VaultChat',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Subtitle
              Text(
                'End-to-end encrypted messaging with zero-knowledge architecture',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // User ID Input (Optional)
              TextField(
                controller: _userIdController,
                decoration: InputDecoration(
                  labelText: 'User ID (optional)',
                  hintText: 'Leave empty for auto-generated ID',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Generate Button
              ElevatedButton(
                onPressed: _isGenerating ? null : _generateIdentity,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isGenerating
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Generate Identity & Start',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
              const SizedBox(height: 32),

              // Info Cards
              _InfoCard(
                icon: Icons.key,
                title: 'RSA-2048 Encryption',
                subtitle: 'Military-grade encryption for all messages',
              ),
              const SizedBox(height: 12),
              _InfoCard(
                icon: Icons.visibility_off,
                title: 'Zero-Knowledge',
                subtitle: 'Server never sees your messages',
              ),
              const SizedBox(height: 12),
              _InfoCard(
                icon: Icons.delete_outline,
                title: 'Self-Destructing',
                subtitle: 'Messages auto-delete after 7 days',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: Theme.of(context).colorScheme.primary,
            size: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}