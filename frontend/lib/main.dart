import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'app/bootstrap.dart';
import 'app/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  bool success = false;
  String? error;

  try {
    // Initialize all services
    success = await Bootstrap.initialize();
  } catch (e) {
    debugPrint('🛑 CRITICAL BOOTSTRAP FAILURE: $e');
    error = e.toString();
  }
  
  runApp(
    ProviderScope(
      child: error != null 
        ? ErrorApp(message: error)
        : const VaultChatApp(),
    ),
  );
}

class ErrorApp extends StatelessWidget {
  final String message;
  const ErrorApp({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFF121212),
        body: Center(
          child: Padding(
             padding: const EdgeInsets.all(32),
             child: Column(
               mainAxisAlignment: MainAxisAlignment.center,
               children: [
                 const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 64),
                 const SizedBox(height: 16),
                 const Text('Initialization Error', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                 const SizedBox(height: 16),
                 Text(message, style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.center),
                 const SizedBox(height: 32),
                 ElevatedButton(
                   onPressed: () async {
                     // Try one-time reset if it's a storage conflict
                     await Hive.deleteBoxFromDisk('messages');
                     await Hive.deleteBoxFromDisk('chat_rooms');
                     // In a real browser this would need a reload
                   },
                   child: const Text('Reset Local Data & Retry'),
                 ),
               ],
             ),
          ),
        ),
      ),
    );
  }
}
