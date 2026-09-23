import 'package:flutter/material.dart';
import '../../../customer/presentation/customer_shell.dart';
import '../../../farmer/presentation/farmer_shell.dart';
import '../../../auth/data/services/auth_service.dart';

/// Landing screen after login — routes to the role-specific shell.
class HomeScreen extends StatelessWidget {
  final String fullName;
  final String role;

  const HomeScreen({super.key, required this.fullName, required this.role});

  @override
  Widget build(BuildContext context) {
    switch (role.toUpperCase()) {
      case 'CUSTOMER':
        return CustomerShell(fullName: fullName);
      case 'FARMER':
        return FarmerShell(fullName: fullName);
      default:
        return _UnsupportedRoleScreen(fullName: fullName, role: role);
    }
  }
}

class _UnsupportedRoleScreen extends StatelessWidget {
  final String fullName;
  final String role;

  const _UnsupportedRoleScreen({required this.fullName, required this.role});

  Future<void> _logout(BuildContext context) async {
    await AuthService.instance.logout();
  }

  @override
  Widget build(BuildContext context) {
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
        child: Text(
          'No dashboard is available yet for the "$role" role.',
          style: const TextStyle(color: Colors.grey),
        ),
      ),
    );
  }
}
