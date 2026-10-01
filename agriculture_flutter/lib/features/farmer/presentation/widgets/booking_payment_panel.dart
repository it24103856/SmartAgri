import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../core/network/api_client.dart';
import '../../../auth/data/services/profile_photo.dart';

class BookingPaymentPanel extends StatefulWidget {
  final int bookingId;
  final bool isOrder;
  final int refreshRevision;
  final Future<void> Function() onChanged;

  const BookingPaymentPanel({
    super.key,
    required this.bookingId,
    this.isOrder = false,
    this.refreshRevision = 0,
    required this.onChanged,
  });

  @override
  State<BookingPaymentPanel> createState() => _BookingPaymentPanelState();
}

class _BookingPaymentPanelState extends State<BookingPaymentPanel> {
  final _reference = TextEditingController();

  Map<String, dynamic>? _summary;
  ProfilePhoto? _receipt;
  bool _busy = false;
  String? _error;

  Dio get _dio => ApiClient.instance.dio;
  String get _base => widget.isOrder ? '/order-payments' : '/package-payments';
  String get _resource =>
      '$_base/${widget.isOrder ? 'orders' : 'bookings'}/${widget.bookingId}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant BookingPaymentPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshRevision != widget.refreshRevision) {
      _load();
    }
  }

  @override
  void dispose() {
    _reference.dispose();
    super.dispose();
  }

  String _message(Object error) {
    if (error is DioException) {
      final body = error.response?.data;

      if (body is Map && body['message'] is String) {
        return body['message'] as String;
      }

      if (body is Map && body['errors'] is Map) {
        return (body['errors'] as Map).values
            .expand((value) => value is List ? value : [value])
            .join('\n');
      }

      return 'Could not complete the request. Please retry.';
    }

    return error.toString();
  }

  String _money(dynamic value) =>
      'Rs. ${((value as num?) ?? 0).toDouble().toStringAsFixed(2)}';

  Future<void> _load() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final response = await _dio.get<dynamic>(_resource);

      if (!mounted) return;

      setState(() {
        _summary = Map<String, dynamic>.from(response.data as Map);
      });
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pick() async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      final photo = await ProfilePhoto.pick();
      if (mounted && photo != null) {
        setState(() => _receipt = photo);
      }
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (_busy) return;

    if (_receipt == null || _reference.text.trim().isEmpty) {
      setState(() {
        _error = 'Select a receipt and enter the bank transaction reference.';
      });
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    var succeeded = false;

    try {
      await _dio.post<dynamic>(
        '$_resource/receipts',
        data: FormData.fromMap({
          'transferReference': _reference.text.trim(),
          'receipt': MultipartFile.fromBytes(
            _receipt!.bytes,
            filename: _receipt!.name,
          ),
        }),
      );

      if (!mounted) return;

      _reference.clear();
      setState(() => _receipt = null);
      succeeded = true;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Receipt submitted. Waiting for admin verification.'),
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }

    if (succeeded && mounted) {
      await _load();
      if (mounted) await widget.onChanged();
    }
  }

  Future<void> _viewReceipt(int id) async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      final response = await _dio.get<List<int>>(
        '$_base/receipts/$id',
        options: Options(responseType: ResponseType.bytes),
      );

      if (!mounted) return;

      final bytes = Uint8List.fromList(response.data!);

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Transfer receipt'),
          content: SizedBox(
            width: 320,
            height: 400,
            child: InteractiveViewer(
              child: Image.memory(
                bytes,
                fit: BoxFit.contain,
                errorBuilder: (_, error, stack) =>
                    const Text('This receipt could not be displayed.'),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    final proofs = (summary?['proofs'] as List?) ?? [];
    final bank = summary?['bank'] as Map?;
    final canSubmit = summary?['canSubmit'] == true;
    final dueStage = summary?['dueStage'];

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.isOrder ? 'Order bank transfer' : 'Package payments',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                onPressed: _busy ? null : _load,
                tooltip: 'Check payment status',
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          if (_busy) const LinearProgressIndicator(),
          if (summary != null) ...[
            Text('Payment: ${summary['paymentStatus']}'),
            if (!widget.isOrder)
              Text('Advance: ${_money(summary['advanceAmount'])}'),
            if (widget.isOrder)
              const Text(
                'Stock is confirmed after bank verification. If stock becomes unavailable, admin will contact you to resolve the payment.',
              ),
            Text('Verified paid: ${_money(summary['amountPaid'])}'),
            Text('Outstanding: ${_money(summary['outstanding'])}'),

            if (summary['status'] == 'PENDING')
              const Text('Wait for admin approval before transferring money.'),

            if (dueStage != null) ...[
              const SizedBox(height: 12),
              Text(
                '$dueStage payment: ${_money(summary['dueAmount'])}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (summary['bankConfigured'] == true)
                SelectableText(
                  'Bank: ${bank?['bankName']}\n'
                  'Account holder: ${bank?['accountName']}\n'
                  'Account number: ${bank?['accountNumber']}\n'
                  'Branch: ${bank?['branch']}',
                )
              else
                const Text('Bank details are not configured. Contact admin.'),
            ],

            for (final raw in proofs) ...[
              const SizedBox(height: 10),
              Text(
                '${raw['stage']} • ${raw['status']} • '
                '${_money(raw['amount'])}',
              ),
              Text('Reference: ${raw['transferReference']}'),
              if (raw['status'] == 'SUBMITTED')
                const Text(
                  'Pending verification. Do not transfer the same amount again.',
                ),
              if (raw['adminNote'] != null) Text('Admin: ${raw['adminNote']}'),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => _viewReceipt((raw['id'] as num).toInt()),
                child: const Text('View receipt'),
              ),
            ],

            if (canSubmit) ...[
              const SizedBox(height: 12),
              const Text(
                'After transferring the exact amount, upload the receipt. '
                'For a rejected receipt, read the reason before making '
                'another transfer.',
              ),
              TextField(
                controller: _reference,
                enabled: !_busy,
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: 'Bank transaction reference',
                ),
              ),
              OutlinedButton.icon(
                onPressed: _busy ? null : _pick,
                icon: const Icon(Icons.upload_file),
                label: Text(
                  _receipt == null ? 'Choose receipt image' : 'Change receipt',
                ),
              ),
              if (_receipt != null)
                Image.memory(_receipt!.bytes, height: 120, fit: BoxFit.contain),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: const Text('Submit for verification'),
              ),
            ],
          ],
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    );
  }
}
