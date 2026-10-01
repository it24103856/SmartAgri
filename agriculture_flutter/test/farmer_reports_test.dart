import 'package:agriculture_flutter/core/network/api_client.dart';
import 'package:agriculture_flutter/features/farmer/presentation/screens/farmer_reports_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('sales period change reloads totals and checkout quantities', (tester) async {
    final dio = ApiClient.instance.dio;
    final original = List<Interceptor>.of(dio.interceptors);
    addTearDown(() => dio.interceptors..clear()..addAll(original));
    final ranges = <String>[];
    dio.interceptors..clear()..add(InterceptorsWrapper(onRequest: (request, handler) {
      ranges.add(request.queryParameters['range'] as String);
      handler.resolve(Response(requestOptions: request, data: {
        'range': ranges.last, 'totalSales': 600, 'totalOrders': 1,
        'products': [{'name': 'Carrots', 'unit': 'kg', 'quantity': 3, 'orders': 1, 'sales': 600}],
      }));
    }));
    await tester.pumpWidget(const MaterialApp(home: FarmerReportsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Carrots'), findsOneWidget);
    expect(find.text('3 kg • 1 orders'), findsOneWidget);
    await tester.tap(find.text('This Month'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('This Week').last);
    await tester.pumpAndSettle();
    expect(ranges, ['This Month', 'This Week']);
  });

  testWidgets('marking approval read refreshes unread count', (tester) async {
    final dio = ApiClient.instance.dio;
    final original = List<Interceptor>.of(dio.interceptors);
    addTearDown(() => dio.interceptors..clear()..addAll(original));
    var read = false;
    dio.interceptors..clear()..add(InterceptorsWrapper(onRequest: (request, handler) {
      if (request.method == 'PUT') {
        expect(request.path, '/farmer-reports/notifications/7/read');
        read = true;
        handler.resolve(Response(requestOptions: request, statusCode: 204));
      } else {
        handler.resolve(Response(requestOptions: request, data: {
          'unreadCount': read ? 0 : 1, 'totalCount': 1,
          'items': [{'id': 7, 'title': 'Product approved', 'message': 'Carrots has been approved.',
            'createdAt': '2026-10-01T00:00:00Z', 'readAt': read ? '2026-10-01T01:00:00Z' : null}],
        }));
      }
    }));
    await tester.pumpWidget(const MaterialApp(home: FarmerReportsScreen(notifications: true)));
    await tester.pumpAndSettle();
    expect(find.text('1 unread'), findsOneWidget);
    await tester.tap(find.text('Mark read'));
    await tester.pumpAndSettle();
    expect(find.text('0 unread'), findsOneWidget);
    expect(find.text('Mark read'), findsNothing);
  });
}
