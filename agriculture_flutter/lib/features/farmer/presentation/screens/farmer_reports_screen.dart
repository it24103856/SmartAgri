import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/network/api_client.dart';

class FarmerReportsScreen extends StatefulWidget {
  final bool notifications;
  const FarmerReportsScreen({super.key, this.notifications = false});

  @override
  State<FarmerReportsScreen> createState() => _FarmerReportsScreenState();
}

class _FarmerReportsScreenState extends State<FarmerReportsScreen> {
  String _range = 'This Month';
  int _page = 1;
  Map<String, dynamic>? _data;
  String? _error;
  bool _busy = false;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response = await ApiClient.instance.dio.get<dynamic>(
        '/farmer-reports/${widget.notifications ? 'notifications' : 'sales'}',
        queryParameters: widget.notifications
            ? {'page': _page}
            : {'range': _range},
      );
      if (mounted && request == _request) {
        setState(() => _data = Map<String, dynamic>.from(response.data as Map));
      }
    } on DioException catch (error) {
      if (mounted && request == _request) {
        setState(
          () => _error =
              error.response?.statusCode == 401 ||
                  error.response?.statusCode == 403
              ? 'Please sign in with an active farmer account.'
              : 'Could not load this page. Check your connection and retry.',
        );
      }
    } finally {
      if (mounted && request == _request) setState(() => _busy = false);
    }
  }

  Future<void> _read(Map item) async {
    try {
      await ApiClient.instance.dio.put<dynamic>(
        '/farmer-reports/notifications/${item['id']}/read',
      );
      if (mounted) await _load();
    } on DioException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not mark notification as read.')),
        );
      }
    }
  }

  String _money(dynamic value) => 'LKR ${(value as num).toStringAsFixed(2)}';
  String _csv(dynamic value) => '"${value.toString().replaceAll('"', '""')}"';

  Future<void> _copyReport() async {
    final rows = _data!['products'] as List;
    final csv = [
      'Period,${_csv(_data!['range'])}',
      'Product,Unit,Quantity,Orders,Sales (LKR)',
      ...rows.map(
        (r) => [
          r['name'],
          r['unit'],
          r['quantity'],
          r['orders'],
          r['sales'],
        ].map(_csv).join(','),
      ),
    ].join('\n');
    await Clipboard.setData(ClipboardData(text: csv));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sales report copied as CSV.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final items =
        (_data?[widget.notifications ? 'items' : 'products'] as List?) ?? [];
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.notifications ? 'Approval notifications' : 'My product sales',
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (!widget.notifications)
              DropdownButtonFormField<String>(
                initialValue: _range,
                decoration: const InputDecoration(labelText: 'Report period'),
                items: ['This Week', 'This Month', 'Last 6 Months', 'This Year']
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: _busy
                    ? null
                    : (value) {
                        setState(() => _range = value!);
                        _load();
                      },
              ),
            if (_busy) const LinearProgressIndicator(),
            if (_error != null) ...[
              Text(_error!),
              TextButton(onPressed: _load, child: const Text('Retry')),
            ] else if (_data != null && !_busy) ...[
              if (widget.notifications)
                Text('${_data!['unreadCount']} unread')
              else ...[
                const SizedBox(height: 16),
                Text(
                  _money(_data!['totalSales']),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                Text('${_data!['totalOrders']} paid orders'),
                const Text(
                  'Sales use payment dates and checkout prices. Delivery fees are excluded. Times use Asia/Colombo. This is sales value, not farmer payout or profit.',
                ),
                TextButton.icon(
                  onPressed: _copyReport,
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy report as CSV'),
                ),
              ],
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Text(
                    widget.notifications
                        ? 'No approval notifications yet.'
                        : 'No paid product sales in this period.',
                  ),
                ),
              for (final item in items)
                Card(
                  child: widget.notifications
                      ? ListTile(
                          leading: Icon(
                            item['readAt'] == null
                                ? Icons.notifications_active
                                : Icons.notifications_none,
                          ),
                          title: Text(item['title'] as String),
                          subtitle: Text(
                            '${item['message']}\n${DateTime.parse(item['createdAt'] as String).toUtc().add(const Duration(hours: 5, minutes: 30)).toString().split('.').first} (Colombo)',
                          ),
                          trailing: item['readAt'] == null
                              ? TextButton(
                                  onPressed: () => _read(item as Map),
                                  child: const Text('Mark read'),
                                )
                              : null,
                        )
                      : ListTile(
                          title: Text(item['name'] as String),
                          subtitle: Text(
                            '${item['quantity']} ${item['unit']} • ${item['orders']} orders',
                          ),
                          trailing: Text(_money(item['sales'])),
                        ),
                ),
              if (widget.notifications)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: _page > 1
                          ? () {
                              _page--;
                              _load();
                            }
                          : null,
                      child: const Text('Previous'),
                    ),
                    Text('Page $_page'),
                    TextButton(
                      onPressed: _page * 30 < (_data!['totalCount'] as int)
                          ? () {
                              _page++;
                              _load();
                            }
                          : null,
                      child: const Text('Next'),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }
}
