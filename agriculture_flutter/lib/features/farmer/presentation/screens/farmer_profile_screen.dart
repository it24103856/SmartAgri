import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/token_storage.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../auth/data/services/auth_service.dart';
import '../../../profile/presentation/edit_profile_screen.dart';
import '../../../profile/presentation/widgets/profile_avatar.dart';
import '../../data/services/farmer_profile_service.dart';
import '../widgets/farmer_ui.dart';

class FarmerProfileScreen extends StatefulWidget {
  final String fullName;
  final ValueChanged<UserModel>? onUpdated;

  const FarmerProfileScreen({
    super.key,
    required this.fullName,
    this.onUpdated,
  });

  @override
  State<FarmerProfileScreen> createState() => _FarmerProfileScreenState();
}

class _FarmerProfileScreenState extends State<FarmerProfileScreen> {
  late Future<UserModel> _future;

  bool _editing = false;
  bool _signingOut = false;

  bool get _busy => _editing || _signingOut;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<UserModel> _load() async {
    final user = await FarmerProfileService.instance.load();

    if (!mounted) return user;

    try {
      await TokenStorage.instance.updateIdentity(
        fullName: user.fullName,
        email: user.email,
      );
    } catch (_) {
      // Server data is still available if local cache updating fails.
    }

    if (mounted) widget.onUpdated?.call(user);

    return user;
  }

  void _reload() {
    if (!mounted || _busy) return;
    setState(() => _future = _load());
  }

  Future<void> _edit(UserModel user) async {
    if (_busy) return;

    setState(() => _editing = true);

    try {
      final updated = await Navigator.of(context).push<UserModel>(
        MaterialPageRoute<UserModel>(
          builder: (_) => EditProfileScreen(user: user, isFarmer: true),
        ),
      );

      if (!mounted || updated == null) return;

      setState(() {
        _future = Future<UserModel>.value(updated);
      });

      widget.onUpdated?.call(updated);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully.')),
      );
    } finally {
      if (mounted) setState(() => _editing = false);
    }
  }

  Future<void> _logout() async {
    if (_busy) return;
    setState(() => _signingOut = true);

    try {
      await AuthService.instance.logout();
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not sign out. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  Widget _detail(IconData icon, String title, String? value) {
    final text = value?.trim() ?? '';

    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title),
      subtitle: Text(text.isEmpty ? 'Not added' : text),
    );
  }

  Widget _profile(UserModel user) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          elevation: 0,
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Stack(
                  children: [
                    ProfileAvatar(imageUrl: user.profileImageUrl, size: 112),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: IconButton.filled(
                        tooltip: 'Change profile photo',
                        onPressed: _busy ? null : () => _edit(user),
                        icon: const Icon(Icons.photo_camera_outlined, size: 20),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  user.fullName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  user.email,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                const Chip(
                  avatar: Icon(Icons.agriculture_outlined, size: 18),
                  label: Text('Farmer account'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Card(
          elevation: 0,
          color: AppColors.surface,
          child: Column(
            children: [
              _detail(Icons.person_outline, 'Full name', user.fullName),
              _detail(Icons.phone_outlined, 'Phone', user.phone),
              _detail(Icons.location_on_outlined, 'Address', user.address),
              _detail(Icons.location_city_outlined, 'City', user.city),
              _detail(Icons.map_outlined, 'Province', user.province),
            ],
          ),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: _busy ? null : () => _edit(user),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(48),
          ),
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Edit profile'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return FarmerPage(
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('My Profile'),
          backgroundColor: AppColors.surface,
          actions: [
            IconButton(
              tooltip: 'Refresh profile',
              onPressed: _busy ? null : _reload,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: FutureBuilder<UserModel>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${snapshot.error}',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              onPressed: _busy ? null : _reload,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return _profile(snapshot.requireData);
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _logout,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      minimumSize: const Size.fromHeight(48),
                    ),
                    icon: const Icon(Icons.logout),
                    label: Text(_signingOut ? 'Signing out...' : 'Sign out'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
