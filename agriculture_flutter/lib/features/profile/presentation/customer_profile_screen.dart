import 'package:flutter/material.dart';

import '../../../shared/widgets/catalog_common.dart';
import '../../../shared/widgets/theme_toggle_button.dart';
import '../../auth/data/models/user_model.dart';
import '../../cart/data/cart_service.dart';
import '../../orders/presentation/purchase_order_screen.dart';
import '../data/customer_profile_service.dart';
import 'edit_profile_screen.dart';
import 'widgets/profile_avatar.dart';

class CustomerProfileScreen extends StatefulWidget {
  final ValueChanged<UserModel>? onUpdated;

  const CustomerProfileScreen({super.key, this.onUpdated});

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  late Future<UserModel> _future;

  bool _signingOut = false;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<UserModel> _load() async {
    final user = await CustomerProfileService.instance.load();

    if (mounted) widget.onUpdated?.call(user);

    return user;
  }

  void _reload() {
    if (!mounted) return;

    final next = _load();

    setState(() {
      _future = next;
    });
  }

  Future<void> _edit(UserModel user, {bool address = false}) async {
    if (_editing || _signingOut) return;

    setState(() {
      _editing = true;
    });

    try {
      final updated = await Navigator.of(context).push<UserModel>(
        MaterialPageRoute<UserModel>(
          builder: (_) => EditProfileScreen(user: user, focusAddress: address),
        ),
      );

      if (!mounted || updated == null) return;

      setState(() {
        _future = Future<UserModel>.value(updated);
      });

      widget.onUpdated?.call(updated);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile updated')));
    } finally {
      if (mounted) {
        setState(() {
          _editing = false;
        });
      }
    }
  }

  Future<void> _signOut() async {
    if (_signingOut) return;

    setState(() {
      _signingOut = true;
    });

    try {
      await signOutCustomer(context);
      CartService.instance.productCount.value = 0;
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not sign out. Please try again.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _signingOut = false;
        });
      }
    }
  }

  Widget _menuItem({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    final colors = Theme.of(context).colorScheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: colors.primaryContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: colors.primary),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: subtitle == null
          ? null
          : Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: _signingOut || _editing ? null : onTap,
    );
  }

  Widget _profile(UserModel user) {
    final colors = Theme.of(context).colorScheme;

    final address = [
      user.address,
      user.city,
      user.province,
    ].whereType<String>().where((text) => text.trim().isNotEmpty).join(', ');

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [colors.primaryContainer, colors.surface],
            ),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Column(
            children: [
              Stack(
                children: [
                  ProfileAvatar(imageUrl: user.profileImageUrl, size: 108),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: IconButton.filled(
                      tooltip: 'Edit profile photo',
                      onPressed: _editing || _signingOut
                          ? null
                          : () => _edit(user),
                      icon: const Icon(Icons.edit_outlined, size: 19),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              Text(
                user.fullName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.onSurface,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                user.email,
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.onSurfaceVariant),
              ),

              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  'SmartAgri Customer',
                  style: TextStyle(
                    color: colors.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 22),

        Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          color: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(color: colors.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _menuItem(
                icon: Icons.person_outline,
                title: 'Edit Profile',
                subtitle: 'Name, phone and profile photo',
                onTap: () => _edit(user),
              ),

              const Divider(height: 1, indent: 74),

              _menuItem(
                icon: Icons.location_on_outlined,
                title: 'My Address',
                subtitle: address.isEmpty
                    ? 'Add your delivery address'
                    : address,
                onTap: () => _edit(user, address: true),
              ),

              const Divider(height: 1, indent: 74),

              _menuItem(
                icon: Icons.receipt_long_outlined,
                title: 'My Orders',
                subtitle: 'View your purchases and payment status',
                onTap: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const PurchaseHistoryScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(
            tooltip: 'Refresh profile',
            onPressed: _signingOut || _editing ? null : _reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: ThemeToggleButton(),
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
                          FilledButton(
                            onPressed: _signingOut ? null : _reload,
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
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.error,
                    foregroundColor: colors.onError,
                  ),
                  onPressed: _signingOut || _editing ? null : _signOut,
                  icon: const Icon(Icons.logout_rounded),
                  label: Text(_signingOut ? 'Signing out…' : 'Sign Out'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
