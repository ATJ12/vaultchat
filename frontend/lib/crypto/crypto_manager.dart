import 'package:openpgp/openpgp.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart' as self_crypto;
import 'dart:convert';
import 'dart:math';
import '../storage/cache/message_cache.dart';
import '../storage/cache/room_storage.dart';
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
  Future<void>? _initFuture;

  static Future<void> initialize() async {
    if (_instance._isInitialized) return;
    if (_instance._initFuture != null) return _instance._initFuture;

    _instance._initFuture = _instance._doInitialize();
    return _instance._initFuture;
  }

  Future<void> _doInitialize() async {
    await _loadKeys();
    _isInitialized = true;
    
    if (_currentPassphrase != null) {
      await unlockStorage(_currentPassphrase!);
    } else {
      // First run or no session: initialize unencrypted
      await MessageCache.initialize();
      await RoomStorage.initialize();
      debugPrint('🔓 Local storage initialized unencrypted');
    }
  }

  Future<void> _loadKeys() async {
    try {
      _privateKey = await SecureStorage.getPrivateKey();
      _publicKey = await SecureStorage.getPublicKey();
      _userId = await SecureStorage.getUserId();
      if (_privateKey != null) {
        // Special internal key for the local vault persistence
        _currentPassphrase = 'permanent_local_vault_key';
      }
    } catch (e) {
      debugPrint('⚠️ Vault: Error loading keys: $e');
    }
  }

  /// Stretched 32-byte key for local DB encryption using PBKDF2
  Future<List<int>> getStorageKey(String passphrase) async {
    final pbkdf2 = self_crypto.Pbkdf2(
      macAlgorithm: self_crypto.Hmac.sha256(),
      iterations: 100000,
      bits: 256,
    );

    // Use a unique salt per installation
    String? saltStr = await SecureStorage.get('local_vault_salt');
    if (saltStr == null) {
      final random = Random.secure();
      final bytes = List<int>.generate(16, (i) => random.nextInt(256));
      saltStr = base64Encode(bytes);
      await SecureStorage.write('local_vault_salt', saltStr);
    }
    
    final salt = base64Decode(saltStr);
    
    final secretKey = await pbkdf2.deriveKeyFromPassword(
      password: passphrase,
      nonce: salt,
    );
    
    return await secretKey.extractBytes();
  }

  Future<String> sign(String data) async {
    if (_privateKey == null) throw StateError('No private key available');
    // For simplicity, we use the session passphrase. 
    // In a real app, we might ask again or use a dedicated signing key.
    return await OpenPGP.sign(data, _privateKey!, _currentPassphrase ?? '');
  }

  Future<void> unlockStorage(String passphrase) async {
    final key = await getStorageKey(passphrase);
    await MessageCache.initialize(encryptionKey: key);
    await RoomStorage.initialize(encryptionKey: key);
    debugPrint('🔐 Local storage unlocked (PBKDF2-100k)');
  }

  Future<bool> hasIdentityKeys() async => _privateKey != null;
  
  void setPassphrase(String pass) {
    _currentPassphrase = pass;
    unlockStorage(pass);
  }

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

    // Ensure storage is unlocked with the new passphrase
    await unlockStorage(passphrase);
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
