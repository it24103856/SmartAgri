import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/network/api_client.dart';
import 'login_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _sent = false;
  bool _busy = false;
  bool _hidePassword = true;

  String? _error;
  String? _notice;

  int _resendSeconds = 0;
  Timer? _timer;

  Options get _publicOptions => Options(extra: {'publicRequest': true});

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';

    if (email.isEmpty) return 'Enter your email address.';

    if (email.length > 254 ||
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Enter a valid email address.';
    }

    return null;
  }

  String _message(Object error) {
    if (error is DioException) {
      if (error.response?.statusCode == 429) {
        return 'Too many requests. Wait a minute and try again.';
      }

      final body = error.response?.data;

      if (body is Map && body['message'] is String) {
        return body['message'] as String;
      }

      if (body is Map && body['errors'] is Map) {
        return (body['errors'] as Map).values
            .expand((value) => value is List ? value : [value])
            .join('\n');
      }
    }

    return 'Could not confirm the request. Check your connection. '
        'If you were resetting your password, try signing in with '
        'the new password before requesting another code.';
  }

  void _startCooldown() {
    _timer?.cancel();
    _resendSeconds = 60;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        if (_resendSeconds > 0) _resendSeconds--;
      });

      if (_resendSeconds == 0) timer.cancel();
    });
  }

  Future<void> _sendCode() async {
    if (_busy || _resendSeconds > 0) return;

    final emailError = _validateEmail(_email.text);
    if (emailError != null) {
      setState(() => _error = emailError);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });

    try {
      final response = await ApiClient.instance.dio.post<dynamic>(
        '/auth/forgot-password',
        data: {'email': _email.text.trim()},
        options: _publicOptions,
      );

      if (!mounted) return;

      setState(() {
        _sent = true;
        _code.clear();
        _notice = response.data['message'] as String;
        _startCooldown();
      });
    } catch (error) {
      if (mounted) {
        setState(() => _error = _message(error));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _resetPassword() async {
    if (_busy || !_formKey.currentState!.validate()) return;

    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });

    try {
      await ApiClient.instance.dio.post<dynamic>(
        '/auth/reset-password',
        data: {
          'email': _email.text.trim(),
          'code': _code.text.trim(),
          'newPassword': _password.text,
        },
        options: _publicOptions,
      );

      if (!mounted) return;

      _password.clear();
      _confirm.clear();

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Password changed'),
          content: const Text(
            'Sign in with your new password. '
            'Your previous login sessions are no longer valid.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Go to Login'),
            ),
          ],
        ),
      );

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    } catch (error) {
      if (mounted) {
        setState(() => _error = _message(error));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _changeEmail() {
    if (_busy) return;

    _timer?.cancel();

    setState(() {
      _sent = false;
      _resendSeconds = 0;
      _error = null;
      _notice = null;
      _code.clear();
      _password.clear();
      _confirm.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(_sent ? 'Reset password' : 'Forgot password')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.lock_reset_rounded, size: 72, color: colors.primary),
                const SizedBox(height: 24),
                Text(
                  _sent ? 'Check your email' : 'Let’s recover your account',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 10),
                Text(
                  _sent
                      ? 'Enter the latest 8-digit code and a new password. '
                            'The code expires after 10 minutes.'
                      : 'Enter the email address you used to register.',
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _email,
                  readOnly: _sent || _busy,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  validator: _validateEmail,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                if (_sent) ...[
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _busy ? null : _changeEmail,
                      child: const Text('Change email'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _code,
                    enabled: !_busy,
                    keyboardType: TextInputType.number,
                    maxLength: 8,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      if (!RegExp(
                        r'^[0-9]{8}$',
                      ).hasMatch(value?.trim() ?? '')) {
                        return 'Enter the 8-digit code.';
                      }
                      return null;
                    },
                    decoration: const InputDecoration(
                      labelText: 'Reset code',
                      prefixIcon: Icon(Icons.pin_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _password,
                    enabled: !_busy,
                    obscureText: _hidePassword,
                    enableSuggestions: false,
                    autocorrect: false,
                    validator: (value) {
                      final password = value ?? '';

                      if (password.length < 12 || password.length > 64) {
                        return 'Use 12–64 characters.';
                      }

                      if (utf8.encode(password).length > 72) {
                        return 'This password is too long in bytes.';
                      }

                      return null;
                    },
                    decoration: InputDecoration(
                      labelText: 'New password',
                      helperText: 'Use a long, unique password.',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            _hidePassword = !_hidePassword;
                          });
                        },
                        icon: Icon(
                          _hidePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirm,
                    enabled: !_busy,
                    obscureText: _hidePassword,
                    enableSuggestions: false,
                    autocorrect: false,
                    validator: (value) {
                      if (value != _password.text) {
                        return 'Passwords do not match.';
                      }
                      return null;
                    },
                    decoration: const InputDecoration(
                      labelText: 'Confirm new password',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),
                ],
                if (_notice != null) ...[
                  const SizedBox(height: 20),
                  Text(_notice!, style: TextStyle(color: colors.primary)),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 20),
                  Text(_error!, style: TextStyle(color: colors.error)),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _busy
                      ? null
                      : (_sent ? _resetPassword : _sendCode),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      _busy
                          ? 'Please wait…'
                          : (_sent ? 'Reset password' : 'Send reset code'),
                    ),
                  ),
                ),
                if (_sent)
                  TextButton(
                    onPressed: _busy || _resendSeconds > 0 ? null : _sendCode,
                    child: Text(
                      _resendSeconds > 0
                          ? 'Resend in $_resendSeconds seconds'
                          : 'Resend code',
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
