import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logger/logger.dart';
import '../storage/secure/secure_storage.dart';
import '../storage/cache/message_cache.dart';
import '../storage/cache/room_storage.dart';
import '../crypto/crypto_manager.dart';

class Bootstrap {
  static final logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 50,
      colors: true,
      printEmojis: true,
    ),
  );

  static Future<bool> initialize() async {
    try {
      logger.i('🚀 Initializing VaultChat...');
      
      // Initialize Hive for local storage
      await Hive.initFlutter();
      logger.d('✓ Hive initialized');
      
      // Initialize secure storage
      await SecureStorage.initialize();
      logger.d('✓ Secure storage initialized');
      
      // Initialize crypto manager (handles storage initialization internally)
      await CryptoManager.initialize();
      logger.d('✓ Crypto manager initialized');
      
      // Check if user has identity keys
      final hasKeys = await CryptoManager.instance.hasIdentityKeys();
      logger.i(hasKeys ? '✓ Identity keys found' : '⚠️  No identity keys');
      
      logger.i('✅ Bootstrap complete');
      
      // Return whether keys exist
      return hasKeys;
    } catch (e, stack) {
      logger.e('❌ Bootstrap failed', error: e, stackTrace: stack);
      rethrow;
    }
  }
}