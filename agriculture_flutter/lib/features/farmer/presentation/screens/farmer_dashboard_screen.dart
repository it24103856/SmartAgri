import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

class FarmerDashboardScreen extends StatelessWidget {
  final String fullName;
  final ValueChanged<int> onOpenTab;

  const FarmerDashboardScreen({
    super.key,
    required this.fullName,
    required this.onOpenTab,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Welcome, $fullName'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Farmer Dashboard',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Manage your farms, get crop recommendations and sell your '
              'harvest.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            _DashboardCard(
              icon: Icons.landscape_outlined,
              title: 'My Farms',
              subtitle: 'Add or edit your farm details',
              onTap: () => onOpenTab(1),
            ),
            const SizedBox(height: 12),
            _DashboardCard(
              icon: Icons.eco_outlined,
              title: 'Crop Recommendations',
              subtitle: 'Coming soon',
              onTap: null,
            ),
            const SizedBox(height: 12),
            _DashboardCard(
              icon: Icons.inventory_2_outlined,
              title: 'My Products',
              subtitle: 'Add products and track admin review',
              onTap: () => onOpenTab(2),
            ),
            const SizedBox(height: 12),
            _DashboardCard(
              icon: Icons.person_outline,
              title: 'Profile',
              subtitle: 'Your account details',
              onTap: () => onOpenTab(3),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _DashboardCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        enabled: onTap != null,
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.soft,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        trailing: onTap == null
            ? null
            : const Icon(Icons.chevron_right, color: AppColors.textSecondary),
      ),
    );
  }
}
