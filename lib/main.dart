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
    print('App lifecycle state: $state, isAuthenticated: $_isAuthenticated');

    switch (state) {
      case AppLifecycleState.paused:
        // App is going to background - record the time
        _lastBackgroundTime = DateTime.now();
        print('App paused at: $_lastBackgroundTime');
        break;
      case AppLifecycleState.resumed:
        // App is coming back to foreground
        print(
          'App resumed, was authenticated: $_isAuthenticated, last background: $_lastBackgroundTime',
        );
        if (_isAuthenticated && _lastBackgroundTime != null) {
          // Check if authentication just happened (within last 5 seconds)
          final now = DateTime.now();
          final justAuthenticated =
              _lastAuthenticationTime != null &&
              now.difference(_lastAuthenticationTime!).inSeconds < 5;

          if (!justAuthenticated) {
            // If user was authenticated and app was backgrounded, require re-auth
            print('Requiring re-authentication');
            setState(() {
              _isAuthenticated = false;
            });
          } else {
            print('Skipping re-auth because user just authenticated');
          }
        }
        break;
      case AppLifecycleState.inactive:
        print('App inactive');
        break;
      case AppLifecycleState.detached:
        print('App detached');
        break;
      case AppLifecycleState.hidden:
        print('App hidden');
        break;
    }
  }

  void _onAuthenticated() {
    print('Authentication successful, setting _isAuthenticated = true');
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
