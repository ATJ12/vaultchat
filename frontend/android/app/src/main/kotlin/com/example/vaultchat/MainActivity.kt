package com.yourcompany.yourapp // MAKE SURE THIS MATCHES YOUR ACTUAL PACKAGE NAME

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "screenshot_protection"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "enableProtection" -> {
                    enableScreenshotProtection()
                    result.success(null)
                }
                "disableProtection" -> {
                    disableScreenshotProtection()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun enableScreenshotProtection() {
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE
        )
    }

    private fun disableScreenshotProtection() {
        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }
}