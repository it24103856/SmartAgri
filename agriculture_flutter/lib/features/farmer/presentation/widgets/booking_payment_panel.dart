import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../core/network/api_client.dart';
import '../../../auth/data/services/profile_photo.dart';
import '../../../orders/data/order_receipt_image.dart';

class BookingPaymentPanel extends StatefulWidget {
  final int bookingId;
  final bool isOrder;
  final int refreshRevision;
  final Future<void> Function() onChanged;
  final Future<ProfilePhoto?> Function()? pickReceipt;

  const BookingPaymentPanel({
    super.key,
    required this.bookingId,
    this.isOrder = false,
    this.refreshRevision = 0,
    required this.onChanged,
    this.pickReceipt,
  });

  @override
  State<BookingPaymentPanel> createState() => _BookingPaymentPanelState();
}

class _BookingPaymentPanelState extends State<BookingPaymentPanel> {
  final _reference = TextEditingController();

  Map<String, dynamic>? _summary;
  ProfilePhoto? _receipt;
  bool _busy = false;
  bool _summaryCurrent = false;
  bool _refreshPending = false;
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
      dynamic body = error.response?.data;
      if (body is List<int>) {
        try {
          body = jsonDecode(utf8.decode(body));
        } on FormatException {
          body = null;
        }
      }

      if (error.response?.statusCode == 401) {
        return 'Your session expired. Please sign in again.';
      }
      if (error.response?.statusCode == 403) {
        return 'You do not have access to this payment or receipt.';
      }

      if (body is Map && body['message'] is String) {
        return body['message'] as String;
      }

      if (body is Map && body['errors'] is Map) {
        return (body['errors'] as Map).values
            .expand((value) => value is List ? value : [value])
            .join('\n');
      }

      if (error.response?.statusCode == 413) {
        return 'Choose a receipt image up to 5 MB.';
      }
      if (error.response == null) {
        return 'Cannot reach SmartAgri. Check your connection and refresh payment status before retrying.';
      }
      return 'Could not complete the request. Please retry.';
    }

    return error.toString();
  }

  String _money(dynamic value) =>
      'Rs. ${((value as num?) ?? 0).toDouble().toStringAsFixed(2)}';

  Future<void> _load() async {
    if (_busy) {
      _refreshPending = true;
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _summaryCurrent = false;
    });

    try {
      await _fetchSummary();
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      _finishOperation();
    }
  }

  Future<void> _fetchSummary() async {
    final response = await _dio.get<dynamic>(_resource);
    if (!mounted) return;
    setState(() {
      _summary = Map<String, dynamic>.from(response.data as Map);
      _summaryCurrent = true;
    });
  }

  void _finishOperation() {
    if (!mounted) return;
    setState(() => _busy = false);
    if (_refreshPending) {
      _refreshPending = false;
      unawaited(_load());
    }
  }

  Future<void> _pick() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final photo =
          await (widget.pickReceipt?.call() ??
              (widget.isOrder ? pickOrderReceipt() : ProfilePhoto.pick()));
      if (mounted && photo != null) {
        final receipt = widget.isOrder
            ? validateOrderReceipt(photo.bytes)
            : photo;
        setState(() => _receipt = receipt);
      }
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      _finishOperation();
    }
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (!_summaryCurrent || _summary?['canSubmit'] != true) return;

    if (_receipt == null || _reference.text.trim().isEmpty) {
      setState(() {
        _error = 'Select a receipt and enter the bank transaction reference.';
      });
      return;
    }
    if (_reference.text.trim().length > 100) {
      setState(
        () => _error = 'Enter a transfer reference of up to 100 characters.',
      );
      return;
    }
    if (widget.isOrder) {
      try {
        _receipt = validateOrderReceipt(_receipt!.bytes);
      } catch (error) {
        setState(() => _error = _message(error));
        return;
      }
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    var submitted = false;

    try {
      await _dio.post<dynamic>(
        '$_resource/receipts',
        data: FormData.fromMap({
          'transferReference': _reference.text.trim(),
          'receipt': MultipartFile.fromBytes(
            _receipt!.bytes,
            filename: _receipt!.name,
            contentType: widget.isOrder
                ? DioMediaType.parse(
                    'image/${_receipt!.name.endsWith('.jpg') ? 'jpeg' : _receipt!.name.split('.').last}',
                  )
                : null,
          ),
        }),
      );

      if (!mounted) return;

      _reference.clear();
      setState(() => _receipt = null);
      submitted = true;
      setState(() => _summaryCurrent = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Receipt submitted. Waiting for admin verification.'),
        ),
      );
      try {
        await _fetchSummary();
      } finally {
        if (mounted) await widget.onChanged();
      }
    } catch (error) {
      if (!mounted) return;
      final message = submitted
          ? 'Receipt submitted, but status could not be refreshed. Check payment status. ${_message(error)}'
          : _message(error);
      setState(() {
        _summaryCurrent = false;
        _error = message;
      });
      // A lost response or conflict can mean the server already accepted proof.
      // Reconcile before allowing another submission; retain the draft on failure.
      if (!submitted) {
        try {
          await _fetchSummary();
        } catch (_) {
          // Keep the original useful error and require a successful refresh.
        }
      }
    } finally {
      _finishOperation();
    }
  }

  Future<void> _viewReceipt(int id) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    Uint8List? receiptBytes;

    try {
      final response = await _dio.get<List<int>>(
        '$_base/receipts/$id',
        options: Options(responseType: ResponseType.bytes),
      );

      if (!mounted) return;

      receiptBytes = Uint8List.fromList(response.data!);
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      _finishOperation();
    }

    final bytes = receiptBytes;
    if (!mounted || bytes == null) return;
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
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    final proofs = (summary?['proofs'] as List?) ?? [];
    final bank = summary?['bank'] as Map?;
    final canSubmit = _summaryCurrent && summary?['canSubmit'] == true;
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
              if (raw['adminNote'] != null)
                Text(
                  '${raw['status'] == 'REJECTED' ? 'Rejection reason' : 'Admin'}: ${raw['adminNote']}',
                ),
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
              const Text('JPG, PNG or WebP, up to 5 MB.'),
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
                Image.memory(
                  _receipt!.bytes,
                  height: 120,
                  fit: BoxFit.contain,
                  errorBuilder: (_, error, stack) => const Text(
                    'This receipt could not be previewed. Choose another image.',
                  ),
                ),
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
