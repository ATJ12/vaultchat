import 'dart:typed_data';
import 'package:pointycastle/export.dart';

class EncryptionService {
  static Uint8List encrypt(Uint8List plaintext, RSAPublicKey publicKey) {
    final encryptor = OAEPEncoding(RSAEngine())
      ..init(
        true,
        PublicKeyParameter<RSAPublicKey>(publicKey),
      );

    return _processInBlocks(encryptor, plaintext);
  }

  static Uint8List _processInBlocks(
    AsymmetricBlockCipher cipher,
    Uint8List data,
  ) {
    final numBlocks = (data.length / cipher.inputBlockSize).ceil();
    final output = <int>[];

    for (var i = 0; i < numBlocks; i++) {
      final start = i * cipher.inputBlockSize;
      final end = (i + 1) * cipher.inputBlockSize;
      final block = data.sublist(
        start,
        end > data.length ? data.length : end,
      );
      
      final encrypted = cipher.process(block);
      output.addAll(encrypted);
    }

    return Uint8List.fromList(output);
  }
}