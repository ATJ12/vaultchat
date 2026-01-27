import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../crypto/crypto_manager.dart';
import '../../services/message_service.dart';
import 'auth_state.dart';

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState.initializing());

  final _messageService = MessageService();

  Future<void> initialize() async {
    try {
      state = const AuthState.initializing();

      final hasKeys = await CryptoManager.instance.hasIdentityKeys();

      if (hasKeys) {
        final userId = CryptoManager.instance.getUserId();
        state = AuthState.ready(userId);
      } else {
        state = const AuthState.noIdentity();
      }
    } catch (e) {
      state = AuthState.error(e.toString());
    }
  }

  Future<void> generateIdentity({String? customUserId}) async {
    try {
      // 1. Create the anonymous ID
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final ghostEmail = 'vault_$timestamp@vaultchat.local';
      final ghostPass = 'permanent_local_vault_key';

      // 2. Call the manager with ALL required arguments
      await CryptoManager.instance.generateIdentityKeys(
        userId: customUserId, // This is optional in our manager
        email: ghostEmail,    // This is REQUIRED
        passphrase: ghostPass, // This is REQUIRED
      );
      
      // 3. Register with backend
      await _messageService.registerCurrentUser();
      
      final userId = CryptoManager.instance.getUserId();
      state = AuthState.ready(userId);
    } catch (e) {
      state = AuthState.error('Failed to generate identity: $e');
    }
  }
  Future<void> deleteIdentity() async {
    try {
      await CryptoManager.instance.clearKeys();
      state = const AuthState.noIdentity();
    } catch (e) {
      state = AuthState.error('Failed to delete identity: $e');
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final notifier = AuthNotifier();
  notifier.initialize();
  return notifier;
});