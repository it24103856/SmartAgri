import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

class MyFarmsScreen extends StatelessWidget {
  const MyFarmsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Farms'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.landscape_outlined, size: 48, color: AppColors.primary),
              SizedBox(height: 12),
              Text(
                'Farm management is coming soon.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
