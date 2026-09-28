import 'package:agriculture_flutter/core/network/api_client.dart';
import 'package:agriculture_flutter/features/farmer/presentation/screens/my_products_screen.dart';
import 'package:agriculture_flutter/features/farmer/presentation/screens/packages_screen.dart';
import 'package:agriculture_flutter/features/farmer/presentation/screens/farm_form_screen.dart';
import 'package:agriculture_flutter/features/farmer/presentation/screens/farmer_dashboard_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> product(int id, String name, String status) => {
  'id': id,
  'name': name,
  'categoryId': 1,
  'categoryName': 'Vegetables',
  'price': 300,
  'unit': 'kg',
  'stockQuantity': 10,
  'status': status,
  'createdAt': '2026-09-26T10:00:00Z',
  'version': 'v1',
  'imageUrls': [],
};

void main() {
  late List<Interceptor> original;
  final requests = <RequestOptions>[];
  setUp(() {
    final dio = ApiClient.instance.dio;
    original = List.of(dio.interceptors);
    dio.interceptors.clear();
    requests.clear();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          requests.add(request);
          Object body = <Object>[];
          if (request.path == '/farmer-products') {
            body = {
              'items': request.queryParameters['page'] == 2
                  ? [product(51, 'Pumpkin', 'REJECTED')]
                  : List.generate(
                      50,
                      (i) => product(i + 1, 'Carrot $i', 'APPROVED'),
                    ),
              'totalCount': 51,
              'page': request.queryParameters['page'],
              'pageSize': 50,
            };
          } else if (request.path == '/farmer-packages') {
            body = [
              {
                'id': 1,
                'name': 'Harvest transport',
                'description': 'Transport your produce safely.',
                'category': 'TRANSPORT',
                'baseRate': 200,
                'isActive': true,
              },
            ];
          } else if (request.path == '/farmer-packages/quote') {
            body = {
              'packageId': 1,
              'category': 'TRANSPORT',
              'calculatedQuantity': 10,
              'quantityUnit': 'km',
              'totalPrice': 2000,
            };
          }
          handler.resolve(
            Response(requestOptions: request, statusCode: 200, data: body),
          );
        },
      ),
    );
  });
  tearDown(() {
    ApiClient.instance.dio.interceptors.clear();
    ApiClient.instance.dio.interceptors.addAll(original);
  });

  testWidgets('inventory search and review filters include later pages', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: MyProductsScreen()));
    await tester.pumpAndSettle();
    expect(requests.where((r) => r.path == '/farmer-products').length, 2);
    await tester.scrollUntilVisible(
      find.byType(TextField),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(find.byType(TextField), 'Pumpkin');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.descendant(of: find.byType(Card), matching: find.text('Pumpkin')),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.descendant(of: find.byType(Card), matching: find.text('Pumpkin')),
      findsOneWidget,
    );
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Approved'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Approved'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('No matching products'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('No matching products'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('changing requirements invalidates a booking estimate', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: PackagesScreen()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('View details & estimate'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(RefreshIndicator).first,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('View details & estimate'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View details & estimate'));
    await tester.pumpAndSettle();
    final distance = find.widgetWithText(TextField, 'Distance (km)');
    await tester.enterText(distance, '10');
    await tester.ensureVisible(find.text('Calculate estimate'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Calculate estimate'));
    await tester.pumpAndSettle();
    expect(find.text('Total: Rs. 2000.00'), findsOneWidget);
    final confirm = find.widgetWithText(
      FilledButton,
      'Confirm booking request',
    );
    expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
    await tester.enterText(distance, '20');
    await tester.pumpAndSettle();
    expect(find.text('Total: Rs. 2000.00'), findsNothing);
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
    await tester.enterText(distance, '-1');
    await tester.ensureVisible(find.text('Calculate estimate'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Calculate estimate'));
    await tester.pumpAndSettle();
    expect(requests.where((r) => r.path.endsWith('/quote')).length, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('farm form fits a narrow phone with larger text', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.2)),
          child: child!,
        ),
        home: const FarmFormScreen(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Register Farm'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard loads real totals on a narrow phone', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: FarmerDashboardScreen(
          fullName: 'Amali Perera',
          onOpenTab: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Product listings'), 160);
    expect(find.text('51'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Explore packages'), 180);
    expect(tester.takeException(), isNull);
  });
}
