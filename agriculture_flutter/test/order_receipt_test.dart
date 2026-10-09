import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:agriculture_flutter/core/network/api_client.dart';
import 'package:agriculture_flutter/core/utils/token_storage.dart';
import 'package:agriculture_flutter/features/farmer/presentation/widgets/booking_payment_panel.dart';
import 'package:agriculture_flutter/features/orders/data/order_receipt_image.dart';
import 'package:agriculture_flutter/features/orders/data/purchase_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

final receiptBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=',
);

Map<String, dynamic> summary({String? proofStatus, bool canSubmit = true}) => {
  'status': 'AwaitingPayment',
  'paymentStatus': 'Pending',
  'amountPaid': 0,
  'outstanding': 375.50,
  'dueStage': 'ORDER',
  'dueAmount': 375.50,
  'canSubmit': canSubmit,
  'bankConfigured': true,
  'bank': {
    'bankName': 'Test bank',
    'accountName': 'AgriLink',
    'accountNumber': '123456',
    'branch': 'Colombo',
  },
  'proofs': [
    if (proofStatus != null)
      {
        'id': 91,
        'stage': 'ORDER',
        'amount': 375.50,
        'status': proofStatus,
        'transferReference': 'BANK-123',
        if (proofStatus == 'REJECTED') 'adminNote': 'Reference is unreadable',
      },
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});
  final dio = ApiClient.instance.dio;
  late List<Interceptor> original;

  setUp(() async {
    original = List.of(dio.interceptors);
    await TokenStorage.instance.saveSession(
      token: 'receipt-test-token',
      role: 'CUSTOMER',
      fullName: 'Customer',
      email: 'customer@test.example',
    );
  });
  tearDown(() async {
    dio.interceptors
      ..clear()
      ..addAll(original);
    await TokenStorage.instance.clearSession();
  });

  Widget panel({
    int revision = 0,
    bool isOrder = true,
    Future<void> Function()? onChanged,
  }) => MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: BookingPaymentPanel(
          bookingId: 42,
          isOrder: isOrder,
          refreshRevision: revision,
          pickReceipt: () async => validateOrderReceipt(receiptBytes),
          onChanged: onChanged ?? () async {},
        ),
      ),
    ),
  );

  Future<void> draft(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField), '  BANK-123  ');
    await tester.ensureVisible(find.text('Choose receipt image'));
    await tester.tap(find.text('Choose receipt image'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Submit for verification'));
  }

  test('receipt validation matches server formats and exact 5 MB limit', () {
    expect(validateOrderReceipt(receiptBytes).bytes, same(receiptBytes));
    expect(validateOrderReceipt(receiptBytes).name, 'receipt.png');
    final jpg = Uint8List(5 * 1024 * 1024)..setRange(0, 3, [255, 216, 255]);
    expect(validateOrderReceipt(jpg).name, 'receipt.jpg');
    final webp = Uint8List(12)
      ..setRange(0, 4, 'RIFF'.codeUnits)
      ..setRange(8, 12, 'WEBP'.codeUnits);
    expect(validateOrderReceipt(webp).name, 'receipt.webp');
    for (final bytes in [
      Uint8List(11),
      Uint8List(12),
      Uint8List(5 * 1024 * 1024 + 1),
    ]) {
      expect(
        () => validateOrderReceipt(bytes),
        throwsA(isA<PurchaseException>()),
      );
    }
    final fakePng = Uint8List(12)..setRange(0, 4, [137, 80, 78, 71]);
    expect(
      () => validateOrderReceipt(fakePng),
      throwsA(isA<PurchaseException>()),
    );
  });

  testWidgets(
    'authenticated upload, preview, duplicate prevention and private viewing',
    (tester) async {
      final post = Completer<void>();
      final refresh = Completer<void>();
      var posted = false;
      var uploads = 0;
      var changed = 0;
      final requests = <RequestOptions>[];
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) async {
            requests.add(request);
            Object? data;
            if (request.method == 'POST') {
              uploads++;
              posted = true;
              final form = request.data as FormData;
              expect(request.path, '/order-payments/orders/42/receipts');
              expect(Map.fromEntries(form.fields), {
                'transferReference': 'BANK-123',
              });
              expect(form.files.single.key, 'receipt');
              expect(form.files.single.value.filename, 'receipt.png');
              expect(
                form.files.single.value.contentType.toString(),
                'image/png',
              );
              expect(
                await form.files.single.value
                    .finalize()
                    .expand((b) => b)
                    .toList(),
                receiptBytes,
              );
              await post.future;
            } else if (request.path == '/order-payments/receipts/91') {
              expect(request.responseType, ResponseType.bytes);
              data = receiptBytes;
            } else {
              if (posted) await refresh.future;
              data = summary(
                proofStatus: posted ? 'SUBMITTED' : null,
                canSubmit: !posted,
              );
            }
            expect(
              request.headers['Authorization'],
              'Bearer receipt-test-token',
            );
            handler.resolve(
              Response(requestOptions: request, statusCode: 200, data: data),
            );
          },
        ),
      );
      await tester.pumpWidget(
        panel(
          onChanged: () async {
            changed++;
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Account number: 123456'), findsOneWidget);
      expect(find.text('ORDER payment: Rs. 375.50'), findsOneWidget);
      await tester.ensureVisible(find.text('Submit for verification'));
      await tester.tap(find.text('Submit for verification'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Select a receipt'), findsOneWidget);
      expect(uploads, 0);
      await draft(tester);
      expect(find.byType(Image), findsOneWidget);
      await tester.tap(find.text('Submit for verification'));
      await tester.pump();
      await tester.tap(find.text('Submit for verification'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(uploads, 1);
      post.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(changed, 0);
      refresh.complete();
      await tester.pumpAndSettle();
      expect(changed, 1);
      expect(find.text('Payment: Pending'), findsOneWidget);
      expect(find.text('Verified paid: Rs. 0.00'), findsOneWidget);
      expect(find.text('Submit for verification'), findsNothing);
      await tester.ensureVisible(find.text('View receipt'));
      await tester.tap(find.text('View receipt'));
      await tester.pumpAndSettle();
      expect(find.text('Transfer receipt'), findsOneWidget);
      expect(
        requests.any((r) => r.path == '/order-payments/receipts/91'),
        isTrue,
      );
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'rejection reason and resubmission follow fresh backend permission',
    (tester) async {
      var allowed = true;
      var fail = false;
      var resubmitted = false;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            if (request.method == 'POST') resubmitted = true;
            if (fail) {
              handler.reject(
                DioException(
                  requestOptions: request,
                  type: DioExceptionType.connectionError,
                ),
              );
            } else {
              handler.resolve(
                Response(
                  requestOptions: request,
                  statusCode: 200,
                  data: summary(
                    proofStatus: resubmitted ? 'SUBMITTED' : 'REJECTED',
                    canSubmit: allowed && !resubmitted,
                  ),
                ),
              );
            }
          },
        ),
      );
      await tester.pumpWidget(panel());
      await tester.pumpAndSettle();
      expect(
        find.text('Rejection reason: Reference is unreadable'),
        findsOneWidget,
      );
      expect(find.text('Submit for verification'), findsOneWidget);
      fail = true;
      await tester.pumpWidget(panel(revision: 1));
      await tester.pumpAndSettle();
      expect(find.text('Submit for verification'), findsNothing);
      expect(find.textContaining('Cannot reach SmartAgri'), findsOneWidget);
      fail = false;
      allowed = false;
      await tester.tap(find.byTooltip('Check payment status'));
      await tester.pumpAndSettle();
      expect(find.text('Submit for verification'), findsNothing);
      allowed = true;
      await tester.tap(find.byTooltip('Check payment status'));
      await tester.pumpAndSettle();
      expect(find.text('Submit for verification'), findsOneWidget);
      await draft(tester);
      await tester.tap(find.text('Submit for verification'));
      await tester.pumpAndSettle();
      expect(resubmitted, isTrue);
      expect(find.text('Submit for verification'), findsNothing);
      expect(find.text('Payment: Pending'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('uncertain submission reconciles accepted proof before retry', (
    tester,
  ) async {
    var accepted = false;
    var uploads = 0;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          if (request.method == 'POST') {
            uploads++;
            accepted = true;
            handler.reject(
              DioException(
                requestOptions: request,
                type: DioExceptionType.receiveTimeout,
              ),
            );
          } else {
            handler.resolve(
              Response(
                requestOptions: request,
                statusCode: 200,
                data: summary(
                  proofStatus: accepted ? 'SUBMITTED' : null,
                  canSubmit: !accepted,
                ),
              ),
            );
          }
        },
      ),
    );
    await tester.pumpWidget(panel());
    await tester.pumpAndSettle();
    await draft(tester);
    await tester.tap(find.text('Submit for verification'));
    await tester.pumpAndSettle();
    expect(uploads, 1);
    expect(find.text('Submit for verification'), findsNothing);
    expect(find.text('Payment: Pending'), findsOneWidget);
    expect(find.textContaining('Pending verification.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'accepted upload with failed refresh stays locked; receipt errors are readable',
    (tester) async {
      var submitted = false;
      var failRefresh = true;
      var changed = 0;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            if (request.method == 'POST') {
              submitted = true;
              handler.resolve(
                Response(requestOptions: request, statusCode: 200),
              );
            } else if (request.path == '/order-payments/receipts/91') {
              handler.reject(
                DioException(
                  requestOptions: request,
                  type: DioExceptionType.badResponse,
                  response: Response(
                    requestOptions: request,
                    statusCode: 404,
                    data: utf8.encode(
                      jsonEncode({'message': 'Receipt not found.'}),
                    ),
                  ),
                ),
              );
            } else if (submitted && failRefresh) {
              handler.reject(
                DioException(
                  requestOptions: request,
                  type: DioExceptionType.connectionError,
                ),
              );
            } else {
              handler.resolve(
                Response(
                  requestOptions: request,
                  statusCode: 200,
                  data: summary(
                    proofStatus: submitted ? 'SUBMITTED' : null,
                    canSubmit: !submitted,
                  ),
                ),
              );
            }
          },
        ),
      );
      await tester.pumpWidget(
        panel(
          onChanged: () async {
            changed++;
          },
        ),
      );
      await tester.pumpAndSettle();
      await draft(tester);
      await tester.tap(find.text('Submit for verification'));
      await tester.pumpAndSettle();
      expect(changed, 1);
      expect(
        find.textContaining(
          'Receipt submitted, but status could not be refreshed.',
        ),
        findsOneWidget,
      );
      expect(find.text('Submit for verification'), findsNothing);
      failRefresh = false;
      await tester.ensureVisible(find.byTooltip('Check payment status'));
      await tester.tap(find.byTooltip('Check payment status'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('View receipt'));
      await tester.tap(find.text('View receipt'));
      await tester.pumpAndSettle();
      expect(find.text('Receipt not found.'), findsOneWidget);
      expect(find.text('Transfer receipt'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('package payment upload keeps its existing routes', (
    tester,
  ) async {
    final requests = <String>[];
    var posted = false;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          requests.add(request.path);
          if (request.method == 'POST') posted = true;
          handler.resolve(
            Response(
              requestOptions: request,
              statusCode: 200,
              data: request.method == 'POST'
                  ? null
                  : summary(canSubmit: !posted),
            ),
          );
        },
      ),
    );
    await tester.pumpWidget(panel(isOrder: false));
    await tester.pumpAndSettle();
    await draft(tester);
    await tester.tap(find.text('Submit for verification'));
    await tester.pumpAndSettle();
    expect(requests, contains('/package-payments/bookings/42/receipts'));
    expect(
      requests.every((path) => path.startsWith('/package-payments/')),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });
}
