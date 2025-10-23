import 'package:flutter/material.dart';
import 'screens/lock_screen.dart';

void main() {
  runApp(const PasswordManagerApp());
}

class PasswordManagerApp extends StatelessWidget {
  const PasswordManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Offline Password Manager',
      theme: ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(primary: Colors.blueAccent),
      ),
      debugShowCheckedModeBanner: false,
      home: const LockScreen(),
    );
  }
}
