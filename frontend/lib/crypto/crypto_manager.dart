import 'dart:convert';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';
import 'package:crypto/crypto.dart';
import '../storage/secure/secure_storage.dart';
import 'primitives/encrypt.dart';
import 'primitives/decrypt.dart';
import 'primitives/hybrid_encrypt.dart';

class CryptoManager {
  static final CryptoManager _instance = CryptoManager._internal();
  static CryptoManager get instance => _instance;
  
  CryptoManager._internal();

  RSAPrivateKey? _privateKey;
  RSAPublicKey? _publicKey;
  String? _userId;

  static Future<void> initialize() async {
    // Load existing keys if they exist
    await _instance._loadKeys();
  }

  Future<void> _loadKeys() async {
    try {
      final privateKeyPem = await SecureStorage.getPrivateKey();
      final publicKeyPem = await SecureStorage.getPublicKey();
      final userId = await SecureStorage.getUserId();
      
      if (privateKeyPem != null && publicKeyPem != null && userId != null) {
        _privateKey = _parsePrivateKey(privateKeyPem);
        _publicKey = _parsePublicKey(publicKeyPem);
        _userId = userId;
        print('✅ Loaded existing keys for user: $_userId');
      } else {
        print('⚠️  No keys found in secure storage');
      }
    } catch (e) {
      print('⚠️  Error loading keys: $e');
      // Keys don't exist yet
    }
  }

  Future<bool> hasIdentityKeys() async {
    return _privateKey != null && _publicKey != null;
  }

  Future<void> generateIdentityKeys({String? userId}) async {
    // Run key generation in compute to prevent blocking UI
    final keyPair = await _generateKeyPairInBackground();
    
    _privateKey = keyPair.privateKey as RSAPrivateKey;
    _publicKey = keyPair.publicKey as RSAPublicKey;
    _userId = userId ?? DateTime.now().millisecondsSinceEpoch.toString();

    // Save to secure storage
    await SecureStorage.savePrivateKey(_encodePrivateKey(_privateKey!));
    await SecureStorage.savePublicKey(_encodePublicKey(_publicKey!));
    await SecureStorage.saveUserId(_userId!);
  }

  Future<AsymmetricKeyPair> _generateKeyPairInBackground() async {
    // This runs on a separate thread
    return Future(() {
      final keyGen = RSAKeyGenerator()
        ..init(ParametersWithRandom(
          RSAKeyGeneratorParameters(BigInt.from(65537), 2048, 64),
          SecureRandom('Fortuna')..seed(KeyParameter(_generateSeed())),
        ));

      return keyGen.generateKeyPair();
    });
  }

  Uint8List _generateSeed() {
    final random = SecureRandom('Fortuna');
    final seeds = List<int>.generate(32, (i) => 
      DateTime.now().millisecondsSinceEpoch % 256);
    random.seed(KeyParameter(Uint8List.fromList(seeds)));
    return random.nextBytes(32);
  }

  Future<void> clearKeys() async {
    _privateKey = null;
    _publicKey = null;
    _userId = null;
    
    await SecureStorage.delete('identity_private_key');
    await SecureStorage.delete('identity_public_key');
    await SecureStorage.delete('user_id');
  }

  String getPublicKeyPem() {
    if (_publicKey == null) throw StateError('No public key available');
    return _encodePublicKey(_publicKey!);
  }

  String? getUserId() => _userId;

  Future<Uint8List> encrypt(Uint8List plaintext, String recipientPublicKeyPem) async {
    final recipientKey = _parsePublicKey(recipientPublicKeyPem);
    
    // For small data (< 190 bytes), use RSA directly
    if (plaintext.length < 190) {
      return EncryptionService.encrypt(plaintext, recipientKey);
    }
    
    // For large data, use hybrid encryption (AES + RSA)
    final package = HybridEncryption.encryptLarge(plaintext, recipientKey);
    
    // Encode the package as JSON, then as bytes
    final packageJson = json.encode(package);
    return Uint8List.fromList(utf8.encode(packageJson));
  }

  Future<Uint8List> decrypt(Uint8List ciphertext) async {
    if (_privateKey == null) throw StateError('No private key available');
    
    // Try to decode as hybrid encryption package
    try {
      final packageJson = utf8.decode(ciphertext);
      final package = json.decode(packageJson) as Map<String, dynamic>;
      
      // Check if it's a hybrid package
      if (package.containsKey('encryptedData') && 
          package.containsKey('encryptedKey') && 
          package.containsKey('iv')) {
        return HybridEncryption.decryptLarge(package, _privateKey!);
      }
    } catch (e) {
      // Not a hybrid package, try RSA directly
    }
    
    // Fall back to RSA decryption for small messages
    return DecryptionService.decrypt(ciphertext, _privateKey!);
  }

  // PEM encoding/decoding helpers
  String _encodePublicKey(RSAPublicKey key) {
    final bytes = _publicKeyToBytes(key);
    final base64 = base64Encode(bytes);
    return '-----BEGIN PUBLIC KEY-----\n$base64\n-----END PUBLIC KEY-----';
  }

  String _encodePrivateKey(RSAPrivateKey key) {
    final bytes = _privateKeyToBytes(key);
    final base64 = base64Encode(bytes);
    return '-----BEGIN PRIVATE KEY-----\n$base64\n-----END PRIVATE KEY-----';
  }

  RSAPublicKey _parsePublicKey(String pem) {
    final lines = pem.split('\n')
      .where((line) => !line.startsWith('-----'))
      .join('');
    final bytes = base64Decode(lines);
    return _publicKeyFromBytes(bytes);
  }

  RSAPrivateKey _parsePrivateKey(String pem) {
    final lines = pem.split('\n')
      .where((line) => !line.startsWith('-----'))
      .join('');
    final bytes = base64Decode(lines);
    return _privateKeyFromBytes(bytes);
  }

  Uint8List _publicKeyToBytes(RSAPublicKey key) {
    // Simple encoding: modulus + exponent
    final modulusBytes = _bigIntToBytes(key.modulus!);
    final exponentBytes = _bigIntToBytes(key.exponent!);
    
    return Uint8List.fromList([
      ...modulusBytes.length.toBytes(4),
      ...modulusBytes,
      ...exponentBytes.length.toBytes(4),
      ...exponentBytes,
    ]);
  }

  Uint8List _privateKeyToBytes(RSAPrivateKey key) {
    final modulusBytes = _bigIntToBytes(key.modulus!);
    final exponentBytes = _bigIntToBytes(key.exponent!);
    final pBytes = _bigIntToBytes(key.p!);
    final qBytes = _bigIntToBytes(key.q!);
    
    return Uint8List.fromList([
      ...modulusBytes.length.toBytes(4),
      ...modulusBytes,
      ...exponentBytes.length.toBytes(4),
      ...exponentBytes,
      ...pBytes.length.toBytes(4),
      ...pBytes,
      ...qBytes.length.toBytes(4),
      ...qBytes,
    ]);
  }

  RSAPublicKey _publicKeyFromBytes(Uint8List bytes) {
    var offset = 0;
    final modulusLen = bytes.sublist(offset, offset + 4).toInt();
    offset += 4;
    final modulus = _bytesToBigInt(bytes.sublist(offset, offset + modulusLen));
    offset += modulusLen;
    final exponentLen = bytes.sublist(offset, offset + 4).toInt();
    offset += 4;
    final exponent = _bytesToBigInt(bytes.sublist(offset, offset + exponentLen));
    
    return RSAPublicKey(modulus, exponent);
  }

  RSAPrivateKey _privateKeyFromBytes(Uint8List bytes) {
    var offset = 0;
    final modulusLen = bytes.sublist(offset, offset + 4).toInt();
    offset += 4;
    final modulus = _bytesToBigInt(bytes.sublist(offset, offset + modulusLen));
    offset += modulusLen;
    final exponentLen = bytes.sublist(offset, offset + 4).toInt();
    offset += 4;
    final exponent = _bytesToBigInt(bytes.sublist(offset, offset + exponentLen));
    offset += exponentLen;
    final pLen = bytes.sublist(offset, offset + 4).toInt();
    offset += 4;
    final p = _bytesToBigInt(bytes.sublist(offset, offset + pLen));
    offset += pLen;
    final qLen = bytes.sublist(offset, offset + 4).toInt();
    offset += 4;
    final q = _bytesToBigInt(bytes.sublist(offset, offset + qLen));
    
    return RSAPrivateKey(modulus, exponent, p, q);
  }

  Uint8List _bigIntToBytes(BigInt number) {
    final bytes = <int>[];
    var n = number;
    while (n > BigInt.zero) {
      bytes.insert(0, (n & BigInt.from(0xff)).toInt());
      n = n >> 8;
    }
    return Uint8List.fromList(bytes.isEmpty ? [0] : bytes);
  }

  BigInt _bytesToBigInt(Uint8List bytes) {
    var result = BigInt.zero;
    for (var byte in bytes) {
      result = (result << 8) | BigInt.from(byte);
    }
    return result;
  }
}

extension on int {
  List<int> toBytes(int length) {
    final bytes = <int>[];
    var value = this;
    for (var i = 0; i < length; i++) {
      bytes.insert(0, value & 0xff);
      value >>= 8;
    }
    return bytes;
  }
}

extension on Uint8List {
  int toInt() {
    var result = 0;
    for (var byte in this) {
      result = (result << 8) | byte;
    }
    return result;
  }
}