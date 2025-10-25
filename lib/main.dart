import 'package:flutter/material.dart';
import 'screens/lock_screen.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const PasswordManagerApp());
}

class PasswordManagerApp extends StatefulWidget {
  const PasswordManagerApp({super.key});

  @override
  State<PasswordManagerApp> createState() => _PasswordManagerAppState();
}

class _PasswordManagerAppState extends State<PasswordManagerApp>
    with WidgetsBindingObserver {
  bool _isAuthenticated = false;
  DateTime? _lastBackgroundTime;
  DateTime? _lastAuthenticationTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        // App is going to background - record the time
        _lastBackgroundTime = DateTime.now();
        break;
      case AppLifecycleState.resumed:
        if (_isAuthenticated && _lastBackgroundTime != null) {
          // Check if authentication just happened (within last 5 seconds)
          final now = DateTime.now();
          final justAuthenticated =
              _lastAuthenticationTime != null &&
              now.difference(_lastAuthenticationTime!).inSeconds < 5;

          if (!justAuthenticated) {
            setState(() {
              _isAuthenticated = false;
            });
          } else {}
        }
        break;
      case AppLifecycleState.inactive:
        break;
      case AppLifecycleState.detached:
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }

  void _onAuthenticated() {
    _lastAuthenticationTime = DateTime.now();
    setState(() {
      _isAuthenticated = true;
    });
  }

  void _onLogout() {
    setState(() {
      _isAuthenticated = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Offline Password Manager',
      theme: ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(primary: Colors.blueAccent),
      ),
      debugShowCheckedModeBanner: false,
      home: _isAuthenticated
          ? HomeScreen(onLogout: _onLogout)
          : LockScreen(onAuthenticated: _onAuthenticated),
    );
  }
}
