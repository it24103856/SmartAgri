import 'package:flutter/material.dart';
import '../widgets/farmer_ui.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../auth/data/services/auth_service.dart';

class FarmerProfileScreen extends StatelessWidget {
  final String fullName;

  const FarmerProfileScreen({super.key, required this.fullName});

  Future<void> _logout(BuildContext context) async {
    await AuthService.instance.logout();
  }

  @override
  Widget build(BuildContext context) {
    return FarmerPage(
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Profile'),
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const FarmerHero(
                eyebrow: 'Your account',
                title: 'Rooted in your community.',
                subtitle: 'Your personal space on SmartAgri.',
                icon: Icons.person_outline,
              ),
              const FarmerSection('Farmer profile'),
              CircleAvatar(
                radius: 36,
                backgroundColor: AppColors.soft,
                child: Text(
                  fullName.isEmpty ? '?' : fullName[0].toUpperCase(),
                  style: const TextStyle(
                    fontSize: 28,
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                fullName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const Text(
                'Farmer account',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ACCOUNT DETAILS',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.4,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.badge_outlined,
                        color: AppColors.primary,
                      ),
                      title: const Text('Full name'),
                      subtitle: Text(fullName),
                    ),
                    const Divider(color: AppColors.border),
                    const ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.eco_outlined,
                        color: AppColors.primary,
                      ),
                      title: Text('Account type'),
                      subtitle: Text('Farmer'),
                    ),
                  ],
                ),
              ),
              const FarmerSection('Session'),
              OutlinedButton.icon(
                onPressed: () => _logout(context),
                icon: const Icon(Icons.logout, color: AppColors.error),
                label: const Text(
                  'Log out',
                  style: TextStyle(color: AppColors.error),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.error),
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
