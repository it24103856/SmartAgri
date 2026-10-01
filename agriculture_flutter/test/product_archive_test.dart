import 'package:agriculture_flutter/core/network/api_client.dart';
import 'package:agriculture_flutter/features/farmer/presentation/screens/my_products_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'archive requires confirmation and updates stock/status filters',
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
      final product = <String, dynamic>{
        'id': 1,
        'name': 'Carrots',
        'categoryId': 1,
        'categoryName': 'Vegetables',
        'price': 300,
        'unit': 'kg',
        'stockQuantity': 3,
        'status': 'APPROVED',
        'createdAt': '2026-09-30T10:00:00Z',
        'version': 'v1',
        'imageUrls': <String>[],
      };
      var archiveRequests = 0;
      dio.interceptors
        ..clear()
        ..add(
          InterceptorsWrapper(
            onRequest: (request, handler) {
              Object data;
              if (request.path.endsWith('/archive')) {
                archiveRequests++;
                expect(request.method, 'POST');
                expect(request.data, {'version': 'v1'});
                product['status'] = 'ARCHIVED';
                product['version'] = 'v2';
                data = Map.of(product);
              } else {
                data = {
                  'items': [Map.of(product)],
                  'totalCount': 1,
                  'page': 1,
                  'pageSize': 50,
                };
              }
              handler.resolve(
                Response(requestOptions: request, statusCode: 200, data: data),
              );
            },
          ),
        );

      await tester.pumpWidget(const MaterialApp(home: MyProductsScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Low stock: 3 left'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilterChip, 'Low / no stock (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Carrots'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Archive'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Keep product'));
      await tester.pumpAndSettle();
      expect(archiveRequests, 0);

      await tester.tap(find.widgetWithText(TextButton, 'Archive'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.widgetWithText(FilledButton, 'Archive'));
      await tester.pumpAndSettle();
      expect(archiveRequests, 1);
      expect(find.text('Low / no stock (0)'), findsOneWidget);
      expect(find.text('No matching products'), findsOneWidget);

      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Archived'));
      await tester.pumpAndSettle();
      expect(find.text('Carrots'), findsOneWidget);
      expect(find.text('Edit & resubmit'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Archive'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
