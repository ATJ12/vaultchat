import 'dart:convert';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';
import 'package:crypto/crypto.dart';

/// Hybrid encryption: AES-256 for data, RSA for AES key
class HybridEncryption {
  
  /// Encrypt large data using AES-256, then encrypt AES key with RSA
  static Map<String, dynamic> encryptLarge(
    Uint8List plaintext,
    RSAPublicKey recipientPublicKey,
  ) {
    // 1. Generate random AES key (256-bit)
    final aesKey = _generateRandomKey(32);
    
    // 2. Generate random IV (128-bit)
    final iv = _generateRandomKey(16);
    
    // 3. Encrypt data with AES-256-CBC
    final encryptedData = _aesEncrypt(plaintext, aesKey, iv);
    
    // 4. Encrypt AES key with RSA
    final rsaEncryptor = OAEPEncoding(RSAEngine())
      ..init(true, PublicKeyParameter<RSAPublicKey>(recipientPublicKey));
    final encryptedKey = rsaEncryptor.process(aesKey);
    
    // 5. Return encrypted package
    return {
      'encryptedData': base64Encode(encryptedData),
      'encryptedKey': base64Encode(encryptedKey),
      'iv': base64Encode(iv),
    };
  }
  
  /// Decrypt large data: decrypt AES key with RSA, then decrypt data with AES
  static Uint8List decryptLarge(
    Map<String, dynamic> encryptedPackage,
    RSAPrivateKey privateKey,
  ) {
    // 1. Decode components
    final encryptedData = base64Decode(encryptedPackage['encryptedData']);
    final encryptedKey = base64Decode(encryptedPackage['encryptedKey']);
    final iv = base64Decode(encryptedPackage['iv']);
    
    // 2. Decrypt AES key with RSA
    final rsaDecryptor = OAEPEncoding(RSAEngine())
      ..init(false, PrivateKeyParameter<RSAPrivateKey>(privateKey));
    final aesKey = rsaDecryptor.process(Uint8List.fromList(encryptedKey));
    
    // 3. Decrypt data with AES
    return _aesDecrypt(Uint8List.fromList(encryptedData), aesKey, iv);
  }
  
  static Uint8List _generateRandomKey(int length) {
    final random = SecureRandom('Fortuna');
    final seed = Uint8List(32);
    final now = DateTime.now().millisecondsSinceEpoch;
    for (var i = 0; i < 32; i++) {
      seed[i] = ((now >> (i * 8)) ^ (now >> 16)) & 0xFF;
    }
    random.seed(KeyParameter(seed));
    return random.nextBytes(length);
  }
  
  static Uint8List _aesEncrypt(Uint8List data, Uint8List key, Uint8List iv) {
    final cipher = PaddedBlockCipherImpl(
      PKCS7Padding(),
      CBCBlockCipher(AESEngine()),
    )..init(
        true,
        PaddedBlockCipherParameters(
          ParametersWithIV(KeyParameter(key), iv),
          null,
        ),
      );
    
    return cipher.process(data);
  }
  
  static Uint8List _aesDecrypt(Uint8List data, Uint8List key, Uint8List iv) {
    final cipher = PaddedBlockCipherImpl(
      PKCS7Padding(),
      CBCBlockCipher(AESEngine()),
    )..init(
        false,
        PaddedBlockCipherParameters(
          ParametersWithIV(KeyParameter(key), iv),
          null,
        ),
      );
    
    return cipher.process(data);
  }
}