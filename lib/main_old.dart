import 'package:flutter/material.dart';
import 'screens/chat_screen.dart';

void main() {
  runApp(const MailMindApp());
}

class MailMindApp extends StatelessWidget {
  const MailMindApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MailMind',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const ChatScreen(),
    );
  }
}
