import 'package:flutter/material.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/utils/token_storage.dart';
import '../../data/models/user_model.dart';
import '../../../home/presentation/screens/home_screen.dart';
import 'login_screen.dart';

class SessionRestoreScreen extends StatefulWidget {
  const SessionRestoreScreen({super.key});

  @override
  State<SessionRestoreScreen> createState() => _SessionRestoreScreenState();
}

class _SessionRestoreScreenState extends State<SessionRestoreScreen> {
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    if (_busy) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final storage = TokenStorage.instance;
      await storage.initialize();

      if (!mounted) return;

      if (!await storage.hasSession()) {
        _open(const LoginScreen());
        return;
      }

      final version = storage.version;
      final data = await ApiClient.instance.validateSession();

      if (!mounted) return;

      if (data == null) {
        if (!await storage.hasSession()) {
          _open(const LoginScreen());
        }
        return;
      }

      if (storage.version != version) return;

      final user = UserModel.fromJson(data);

      if (!user.isActive || (!user.isCustomer && !user.isFarmer)) {
        await storage.clearSession(expectedVersion: version);
        _open(const LoginScreen());
        return;
      }

      await storage.updateIdentity(fullName: user.fullName, email: user.email);

      if (!mounted || storage.version != version) return;

      _open(HomeScreen(fullName: user.fullName, role: user.role));
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error =
            'We could not verify your session. '
            'Check your connection and try again. '
            'Your saved login has not been removed.';
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _open(Widget screen) {
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => screen),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.eco_outlined, size: 64, color: colors.primary),
                const SizedBox(height: 20),
                Text(
                  'SmartAgri',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 24),
                if (_busy) ...[
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  const Text('Checking your session…'),
                ] else if (_error != null) ...[
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _restore,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
