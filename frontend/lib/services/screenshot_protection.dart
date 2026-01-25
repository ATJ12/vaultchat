import 'package:flutter/services.dart';

class ScreenshotProtection {
  static const MethodChannel _channel = MethodChannel('screenshot_protection');

  static Future<void> enableProtection() async {
    try {
      await _channel.invokeMethod('enableProtection');
    } on PlatformException catch (e) {
      print("Failed to enable: ${e.message}");
    }
  }

  static Future<void> disableProtection() async {
    try {
      await _channel.invokeMethod('disableProtection');
    } on PlatformException catch (e) {
      print("Failed to disable: ${e.message}");
    }
  }
}