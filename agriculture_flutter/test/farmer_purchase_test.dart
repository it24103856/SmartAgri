import 'package:agriculture_flutter/core/network/api_client.dart';
import 'package:agriculture_flutter/core/utils/token_storage.dart';
import 'package:agriculture_flutter/features/orders/presentation/checkout_screen.dart';
import 'package:agriculture_flutter/features/orders/presentation/purchase_order_screen.dart';
import 'package:agriculture_flutter/features/farmer/presentation/widgets/booking_payment_panel.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});
  setUp(() async {
    await TokenStorage.instance.saveSession(
      token: 'test',
      role: 'FARMER',
      fullName: 'Farmer',
      email: 'farmer@test.example',
    );
  });
  tearDown(() => TokenStorage.instance.clearSession());
  testWidgets('my purchases shows products and opens the selected order', (
    tester,
  ) async {
    final dio = ApiClient.instance.dio;
    final original = List<Interceptor>.of(dio.interceptors);
    addTearDown(() {
      dio.interceptors
        ..clear()
        ..addAll(original);
    });
    final requests = <String>[];
    final order = {
      'id': 42,
      'status': 'Confirmed',
      'fullName': 'Farmer',
      'phone': '0771234567',
      'address': 'Farm road',
      'city': 'Colombo',
      'subtotal': 200,
      'totalAmount': 200,
      'deliveryFee': 0,
      'payment': {'method': 'COD', 'status': 'Unpaid', 'amount': 200},
      'items': [
        {'name': 'Carrots', 'quantity': 2, 'unitPrice': 100, 'lineTotal': 200},
      ],
    };
    dio.interceptors
      ..clear()
      ..add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            requests.add(request.path);
            handler.resolve(
              Response(
                requestOptions: request,
                statusCode: 200,
                data: request.path.endsWith('/tracking')
                    ? {'order': order, 'history': []}
                    : [order],
              ),
            );
          },
        ),
      );
    await tester.pumpWidget(
      const MaterialApp(home: PurchaseHistoryScreen(title: 'My Purchases')),
    );
    await tester.pumpAndSettle();
    expect(find.text('My Purchases'), findsOneWidget);
    expect(find.textContaining('Carrots × 2'), findsOneWidget);
    await tester.tap(find.text('Order #42'));
    await tester.pumpAndSettle();
    expect(find.byType(PurchaseOrderScreen), findsOneWidget);
    expect(requests, contains('/customer-orders/42/tracking'));
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(requests.where((path) => path == '/customer-orders').length, 2);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'receipt status refreshes with order tracking after bank approval',
    (tester) async {
      final dio = ApiClient.instance.dio;
      final original = List<Interceptor>.of(dio.interceptors);
      addTearDown(() {
        dio.interceptors
          ..clear()
          ..addAll(original);
      });
      var approved = false;
      dio.interceptors
        ..clear()
        ..add(
          InterceptorsWrapper(
            onRequest: (request, handler) {
              handler.resolve(
                Response(
                  requestOptions: request,
                  statusCode: 200,
                  data: {
                    'status': approved ? 'Confirmed' : 'AwaitingPayment',
                    'paymentStatus': approved ? 'Paid' : 'Pending',
                    'amountPaid': approved ? 200 : 0,
                    'outstanding': approved ? 0 : 200,
                    'canSubmit': false,
                    'proofs': [
                      {
                        'id': 1,
                        'stage': 'ORDER',
                        'amount': 200,
                        'status': approved ? 'APPROVED' : 'SUBMITTED',
                        'transferReference': 'BANK-123',
                      },
                    ],
                  },
                ),
              );
            },
          ),
        );
      Widget panel(int revision) => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: BookingPaymentPanel(
              bookingId: 42,
              isOrder: true,
              refreshRevision: revision,
              onChanged: () async {},
            ),
          ),
        ),
      );
      await tester.pumpWidget(panel(0));
      await tester.pumpAndSettle();
      expect(find.text('Payment: Pending'), findsOneWidget);
      approved = true;
      await tester.pumpWidget(panel(1));
      await tester.pumpAndSettle();
      expect(find.text('Payment: Paid'), findsOneWidget);
      expect(find.text('Outstanding: Rs. 0.00'), findsOneWidget);
      expect(find.textContaining('Pending verification.'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'farmer checkout opens bank receipt panel and loads farmer profile',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final dio = ApiClient.instance.dio;
      final original = List<Interceptor>.of(dio.interceptors);
      addTearDown(() {
        dio.interceptors
          ..clear()
          ..addAll(original);
      });
      final requests = <RequestOptions>[];
      final order = {
        'id': 1,
        'status': 'AwaitingPayment',
        'fullName': 'Farmer',
        'email': 'farmer@test.example',
        'phone': '0771234567',
        'address': 'Farm road',
        'city': 'Colombo',
        'subtotal': 200,
        'totalAmount': 200,
        'deliveryFee': 0,
        'createdAt': '2026-10-01T10:00:00Z',
        'payment': {
          'method': 'BANK_TRANSFER',
          'status': 'Pending',
          'amount': 200,
        },
        'items': [
          {
            'name': 'Carrots',
            'quantity': 2,
            'unitPrice': 100,
            'unit': 'kg',
            'lineTotal': 200,
          },
        ],
      };
      dio.interceptors
        ..clear()
        ..add(
          InterceptorsWrapper(
            onRequest: (request, handler) {
              requests.add(request);
              Object data;
              if (request.path.startsWith('/cart')) {
                data = {
                  'subtotal': 200,
                  'canCheckout': true,
                  'items': [
                    {
                      'productId': 1,
                      'name': 'Carrots',
                      'unit': 'kg',
                      'quantity': 2,
                      'unitPrice': 100,
                      'lineTotal': 200,
                      'stockQuantity': 10,
                      'available': true,
                    },
                  ],
                };
              } else if (request.path == '/order-payments/bank-details') {
                data = {
                  'bankConfigured': true,
                  'bank': {
                    'bankName': 'Test bank',
                    'accountName': 'Test',
                    'accountNumber': '123',
                    'branch': 'Test',
                  },
                };
              } else if (request.path == '/farmer-profile') {
                data = {...order, 'role': 'FARMER', 'status': 'ACTIVE'};
              } else if (request.path.endsWith('/tracking')) {
                data = {'order': order, 'history': []};
              } else if (request.path == '/order-payments/orders/1') {
                data = {
                  'status': 'AwaitingPayment',
                  'paymentStatus': 'Pending',
                  'amountPaid': 0,
                  'outstanding': 200,
                  'dueStage': 'ORDER',
                  'dueAmount': 200,
                  'canSubmit': true,
                  'bankConfigured': true,
                  'proofs': [],
                  'bank': {
                    'bankName': 'Test bank',
                    'accountName': 'Test',
                    'accountNumber': '123',
                    'branch': 'Test',
                  },
                };
              } else {
                data = order;
              }
              handler.resolve(
                Response(requestOptions: request, statusCode: 200, data: data),
              );
            },
          ),
        );
      await tester.pumpWidget(const MaterialApp(home: CheckoutScreen()));
      await tester.pumpAndSettle();
      expect(requests.any((r) => r.path == '/farmer-profile'), isTrue);
      expect(requests.any((r) => r.path == '/customer-profile'), isFalse);
      await tester.scrollUntilVisible(
        find.text('Continue to payment'),
        250,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.text('Continue to payment'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Place order & upload receipt'),
        250,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.text('Place order & upload receipt'));
      await tester.pumpAndSettle();
      expect(
        requests
            .singleWhere((r) => r.path == '/customer-orders')
            .data['paymentMethod'],
        'BANK_TRANSFER',
      );
      expect(find.byType(PurchaseOrderScreen), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byType(BookingPaymentPanel),
        250,
        scrollable: find
            .descendant(
              of: find.byType(PurchaseOrderScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(requests.any((r) => r.path == '/order-payments/orders/1'), isTrue);
      expect(find.text('Order bank transfer'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );
}
