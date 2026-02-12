import 'package:openpgp/openpgp.dart';
import 'package:flutter/foundation.dart';
import '../storage/secure/secure_storage.dart';

Future<KeyPair> _generateKeysInIsolate(Map<String, String> data) async {
  final keyOptions = KeyOptions()..rsaBits = 2048;
  return await OpenPGP.generate(
    options: Options()
      ..name = data['name']!
      ..email = data['email']!
      ..passphrase = data['passphrase']!
      ..keyOptions = keyOptions,
  );
}

class CryptoManager {
  static final CryptoManager _instance = CryptoManager._internal();
  static CryptoManager get instance => _instance;

  CryptoManager._internal();

  String? _privateKey;
  String? _publicKey;
  String? _userId;
  String? _currentPassphrase;
  bool _isInitialized = false;

  static Future<void> initialize() async {
    if (_instance._isInitialized) return;
    await _instance._loadKeys();
    _instance._isInitialized = true;
  }

  Future<void> _loadKeys() async {
    try {
      _privateKey = await SecureStorage.getPrivateKey();
      _publicKey = await SecureStorage.getPublicKey();
      _userId = await SecureStorage.getUserId();
      if (_privateKey != null) {
        _currentPassphrase = 'permanent_local_vault_key';
      }
    } catch (e) {
      debugPrint('⚠️ Vault: Error loading keys: $e');
    }
  }

  Future<bool> hasIdentityKeys() async => _privateKey != null;
  void setPassphrase(String pass) => _currentPassphrase = pass;
  String getPassphrase() => _currentPassphrase ?? '';
  String getPublicKeyPem() => _publicKey ?? '';
  String? getUserId() => _userId;

  Future<void> generateIdentityKeys({
    String? userId,
    required String email,
    required String passphrase,
  }) async {
    KeyPair keyPair;
    if (kIsWeb) {
      await Future.delayed(const Duration(milliseconds: 1000));
      final keyOptions = KeyOptions()..rsaBits = 2048;
      keyPair = await OpenPGP.generate(
        options: Options()
          ..name = email.split('@')[0]
          ..email = email
          ..passphrase = passphrase
          ..keyOptions = keyOptions,
      ).timeout(
        const Duration(minutes: 2),
        onTimeout: () => throw Exception('Key generation timed out'),
      );
    } else {
      keyPair = await compute(_generateKeysInIsolate, {
        'name': email.split('@')[0],
        'email': email,
        'passphrase': passphrase,
      });
    }

    _privateKey = keyPair.privateKey;
    _publicKey = keyPair.publicKey;
    _userId = userId ?? email;
    _currentPassphrase = passphrase;

    await SecureStorage.savePrivateKey(_privateKey!);
    await SecureStorage.savePublicKey(_publicKey!);
    await SecureStorage.saveUserId(_userId!);
  }

  Future<String> encrypt(String plaintext, String recipientPublicKey) async {
    if (plaintext.startsWith('PROTOCOL_')) return plaintext;
    return await OpenPGP.encrypt(plaintext, recipientPublicKey);
  }

  Future<String> decrypt(String ciphertext, String passphrase) async {
    if (_privateKey == null) throw StateError('No private key available');
    try {
      return await OpenPGP.decrypt(ciphertext, _privateKey!, passphrase);
    } catch (e) {
      debugPrint('❌ Decryption failed: $e');
      rethrow;
    }
  }

  Future<void> clearKeys() async {
    _privateKey = _publicKey = _userId = _currentPassphrase = null;
    await SecureStorage.clearAll();
    _isInitialized = false;
  }
}
