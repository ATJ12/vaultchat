import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
    webOptions: WebOptions(
      dbName: 'VaultChatStorage',
      publicKey: 'VaultChatSecure',
    ),
  );

  static const _privateKeyKey = 'identity_private_key';
  static const _publicKeyKey = 'identity_public_key';
  static const _userIdKey = 'user_id';
  static const _passphraseKey = 'passphrase'; // ✅ ADD THIS

  static Future<void> initialize() async {
    // Test storage availability
    try {
      await _storage.read(key: 'vault_health_check');
      debugPrint('✓ Secure storage initialized');
    } catch (e) {
      debugPrint('❌ Secure storage error: $e. Using fallback.');
      // On some web environments, specialized storage might fail.
      // We don't throw here to allow Hive (which is our main DB) to at least try.
    }
  }

  // Identity Keys
  static Future<void> savePrivateKey(String privateKeyPem) async {
    await _storage.write(key: _privateKeyKey, value: privateKeyPem);
    print('✓ Private key saved');
  }

  static Future<String?> getPrivateKey() async {
    return await _storage.read(key: _privateKeyKey);
  }

  static Future<void> savePublicKey(String publicKeyPem) async {
    await _storage.write(key: _publicKeyKey, value: publicKeyPem);
    print('✓ Public key saved');
  }

  static Future<String?> getPublicKey() async {
    return await _storage.read(key: _publicKeyKey);
  }

  static Future<void> saveUserId(String userId) async {
    await _storage.write(key: _userIdKey, value: userId);
    print('✓ User ID saved: $userId');
  }

  static Future<String?> getUserId() async {
    return await _storage.read(key: _userIdKey);
  }

  // ✅ ADD THESE TWO METHODS
  /// Save OpenPGP key passphrase
  static Future<void> savePassphrase(String passphrase) async {
    await _storage.write(key: _passphraseKey, value: passphrase);
    print('✓ Passphrase saved');
  }

  /// Get OpenPGP key passphrase
  static Future<String?> getPassphrase() async {
    return await _storage.read(key: _passphraseKey);
  }

  // Session tokens
  static Future<void> saveSessionToken(String token) async {
    await _storage.write(key: 'session_token', value: token);
  }

  static Future<String?> getSessionToken() async {
    return await _storage.read(key: 'session_token');
  }

  // Clear all data
  static Future<void> clearAll() async {
    await _storage.deleteAll();
    print('✓ All secure storage cleared');
  }

  // Generic storage
  static Future<void> write(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  static Future<String?> get(String key) async {
    return await _storage.read(key: key);
  }

  // Delete specific key
  static Future<void> delete(String key) async {
    await _storage.delete(key: key);
  }
}