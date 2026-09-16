import 'dart:async';

import 'package:flutter/material.dart';

import 'core/network/api_client.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'core/utils/token_storage.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/screens/session_restore_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  int _navigationVersion = 0;
  bool _showLogin = false;
  bool _foreground = true;
  Timer? _sessionTimer;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    TokenStorage.instance.sessionEnded.addListener(_onSessionEnded);

    // Detect expiry/account blocking even while the user stays on one page.
    _sessionTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (_foreground) {
        unawaited(_checkSession());
      }
    });
  }

  void _onSessionEnded() {
    if (!mounted) return;

    setState(() {
      _showLogin = true;
      _navigationVersion++;
    });
  }

  Future<void> _checkSession() async {
    try {
      if (!await TokenStorage.instance.hasSession()) return;
      await ApiClient.instance.validateSession();
    } catch (_) {
      // Temporary connection/server errors never sign the user out.
      // Startup failures show Retry on SessionRestoreScreen.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;

    if (_foreground) {
      unawaited(_checkSession());
    }
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    TokenStorage.instance.sessionEnded.removeListener(_onSessionEnded);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.mode,
      builder: (context, mode, child) {
        return MaterialApp(
          // On logout, discard the entire old navigation stack.
          key: ValueKey<int>(_navigationVersion),
          debugShowCheckedModeBanner: false,
          title: 'SmartAgri',
          theme: AppTheme.lightTheme(),
          darkTheme: AppTheme.darkTheme(),
          themeMode: mode,
          routes: {'/login': (_) => const LoginScreen()},
          home: _showLogin ? const LoginScreen() : const SessionRestoreScreen(),
        );
      },
    );
  }
}
