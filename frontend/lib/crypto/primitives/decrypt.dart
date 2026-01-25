import 'dart:typed_data';
import 'package:pointycastle/export.dart';

class DecryptionService {
  static Uint8List decrypt(Uint8List ciphertext, RSAPrivateKey privateKey) {
    final decryptor = OAEPEncoding(RSAEngine())
      ..init(
        false,
        PrivateKeyParameter<RSAPrivateKey>(privateKey),
      );

    return _processInBlocks(decryptor, ciphertext);
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
      
      final decrypted = cipher.process(block);
      output.addAll(decrypted);
    }

    return Uint8List.fromList(output);
  }
}