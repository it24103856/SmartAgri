import 'package:flutter/material.dart';
import '../../../customer/presentation/customer_shell.dart';
import '../../../auth/data/services/auth_service.dart';
import '../../../auth/presentation/screens/login_screen.dart';

/// Temporary landing screen after login — replace with the real
/// Farmer/Customer dashboards once those features are built.
class HomeScreen extends StatelessWidget {
  final String fullName;
  final String role;

  const HomeScreen({super.key, required this.fullName, required this.role});

  Future<void> _logout(BuildContext context) async {
    await AuthService.instance.logout();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (role.toUpperCase() == 'CUSTOMER') {
      return CustomerShell(fullName: fullName);
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF3B6E52),
        title: Text('Welcome, $fullName'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              role == 'FARMER' ? Icons.agriculture : Icons.shopping_bag,
              size: 64,
              color: const Color(0xFF3B6E52),
            ),
            const SizedBox(height: 16),
            Text(
              '$role Dashboard',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'This is a placeholder — build the real dashboard here.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
