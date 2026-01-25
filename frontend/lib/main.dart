import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/bootstrap.dart';
import 'app/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize all services
  await Bootstrap.initialize();
  
  runApp(
    const ProviderScope(
      child: VaultChatApp(),
    ),
  );
}
