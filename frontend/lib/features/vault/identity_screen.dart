import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/auth_state.dart';
import '../../crypto/crypto_manager.dart';

class IdentityScreen extends ConsumerWidget {
  const IdentityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          child: const Text('Generate Identity Keys'),
          onPressed: () async {
            await CryptoManager.instance.generateIdentityKeys();
            ref.read(authStateProvider.notifier).ready();
          },
        ),
      ),
    );
  }
}
