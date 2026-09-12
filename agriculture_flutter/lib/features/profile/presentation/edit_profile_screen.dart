import 'package:flutter/material.dart';

import '../../../core/utils/token_storage.dart';
import '../../../shared/widgets/catalog_common.dart';
import '../../auth/data/models/user_model.dart';
import '../../auth/data/services/profile_photo.dart';
import '../data/customer_profile_service.dart';
import 'widgets/profile_avatar.dart';

class EditProfileScreen extends StatefulWidget {
  final UserModel user;
  final bool focusAddress;

  const EditProfileScreen({
    super.key,
    required this.user,
    this.focusAddress = false,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _form = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _address;
  late final TextEditingController _city;
  late final TextEditingController _province;

  ProfilePhoto? _photo;

  bool _saving = false;
  bool _picking = false;
  String? _error;

  bool get _busy => _saving || _picking;

  @override
  void initState() {
    super.initState();

    _name = TextEditingController(text: widget.user.fullName);
    _phone = TextEditingController(text: widget.user.phone ?? '');
    _address = TextEditingController(text: widget.user.address ?? '');
    _city = TextEditingController(text: widget.user.city ?? '');
    _province = TextEditingController(text: widget.user.province ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    _city.dispose();
    _province.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    if (_busy) return;

    setState(() {
      _picking = true;
      _error = null;
    });

    try {
      final photo = await ProfilePhoto.pick();

      if (!mounted || photo == null) return;

      setState(() {
        _photo = photo;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _picking = false;
        });
      }
    }
  }

  Future<void> _save() async {
    if (_busy || !(_form.currentState?.validate() ?? false)) return;

    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final user = await CustomerProfileService.instance.save(
        fullName: _name.text,
        phone: _phone.text,
        address: _address.text,
        city: _city.text,
        province: _province.text,
        photo: _photo,
      );

      try {
        await TokenStorage.instance.updateIdentity(
          fullName: user.fullName,
          email: user.email,
        );
      } catch (_) {
        // The server update succeeded. The profile remains saved.
      }

      if (!mounted) return;

      Navigator.of(context).pop<UserModel>(user);
    } catch (error) {
      if (!mounted) return;

      if (error is CustomerProfileException &&
          (error.statusCode == 401 || error.statusCode == 403)) {
        await signOutCustomer(context);
        return;
      }

      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    int maxLength = 100,
    int lines = 1,
    bool autofocus = false,
    TextInputType? keyboard,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        enabled: !_busy,
        autofocus: autofocus,
        keyboardType: keyboard,
        maxLength: maxLength,
        maxLines: lines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          counterText: '',
        ),
        validator: (value) {
          final text = value?.trim() ?? '';

          if (text.isEmpty) return '$label is required';

          if (controller == _phone &&
              !RegExp(r'^\+?[0-9][0-9 ()-]{5,23}[0-9]$').hasMatch(text)) {
            return 'Enter a valid phone number';
          }

          return null;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('Edit Profile')),
        body: SafeArea(
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(22),
              children: [
                Center(
                  child: ProfileAvatar(
                    imageUrl: widget.user.profileImageUrl,
                    preview: _photo?.bytes,
                    size: 112,
                  ),
                ),

                TextButton.icon(
                  onPressed: _busy ? null : _pickPhoto,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: Text(_picking ? 'Opening photos…' : 'Change photo'),
                ),

                if (_photo != null)
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () {
                            setState(() {
                              _photo = null;
                            });
                          },
                    child: const Text('Undo photo selection'),
                  ),

                const SizedBox(height: 20),

                _field(
                  _name,
                  'Full name',
                  Icons.person_outline,
                  maxLength: 120,
                ),

                TextFormField(
                  initialValue: widget.user.email,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                    helperText: 'Your sign-in email',
                  ),
                ),

                const SizedBox(height: 20),

                _field(
                  _phone,
                  'Phone number',
                  Icons.phone_outlined,
                  maxLength: 25,
                  keyboard: TextInputType.phone,
                ),

                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Delivery address',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                  ),
                ),

                _field(
                  _address,
                  'Address',
                  Icons.location_on_outlined,
                  maxLength: 250,
                  lines: 2,
                  autofocus: widget.focusAddress,
                  keyboard: TextInputType.streetAddress,
                ),

                _field(_city, 'City', Icons.location_city_outlined),

                _field(_province, 'Province', Icons.map_outlined),

                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(_error!, style: TextStyle(color: colors.error)),
                  ),

                FilledButton.icon(
                  onPressed: _busy ? null : _save,
                  icon: _saving
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.onPrimary,
                          ),
                        )
                      : const Icon(Icons.check_rounded),
                  label: Text(_saving ? 'Saving…' : 'Save Changes'),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
