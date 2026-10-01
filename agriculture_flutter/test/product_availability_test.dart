import 'package:agriculture_flutter/core/network/api_client.dart';
import 'package:agriculture_flutter/features/farmer/presentation/screens/my_products_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final conflict in [false, true]) {
    testWidgets('availability toggle refreshes product (conflict: $conflict)', (
      tester,
    ) async {
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
        'stockQuantity': 10,
        'status': 'APPROVED',
        'isActive': true,
        'createdAt': '2026-09-30T10:00:00Z',
        'version': 'v1',
        'imageUrls': <String>[],
      };
      var updates = 0;
      var reads = 0;
      dio.interceptors
        ..clear()
        ..add(
          InterceptorsWrapper(
            onRequest: (request, handler) {
              if (request.path.endsWith('/availability')) {
                updates++;
                expect(request.method, 'PUT');
                expect(request.data['version'], product['version']);
                if (conflict) {
                  product['isActive'] = false;
                  product['version'] = 'v2';
                  handler.reject(
                    DioException(
                      requestOptions: request,
                      type: DioExceptionType.badResponse,
                      response: Response(
                        requestOptions: request,
                        statusCode: 409,
                        data: {
                          'message': 'Product changed. Refresh and try again.',
                        },
                      ),
                    ),
                  );
                  return;
                }
                product['isActive'] = request.data['isActive'];
                product['version'] = 'v${updates + 1}';
                handler.resolve(
                  Response(
                    requestOptions: request,
                    statusCode: 200,
                    data: Map.of(product),
                  ),
                );
              } else {
                reads++;
                handler.resolve(
                  Response(
                    requestOptions: request,
                    statusCode: 200,
                    data: {
                      'items': [Map.of(product)],
                      'totalCount': 1,
                      'page': 1,
                      'pageSize': 50,
                    },
                  ),
                );
              }
            },
          ),
        );
      await tester.pumpWidget(const MaterialApp(home: MyProductsScreen()));
      await tester.pumpAndSettle();
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue,
      );
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(find.text('Inactive'), findsOneWidget);
      expect(find.text('Hidden from customers'), findsOneWidget);
      expect(reads, 2);
      expect(product['status'], 'APPROVED');
      if (!conflict) {
        await tester.tap(find.byType(Switch));
        await tester.pumpAndSettle();
        expect(find.text('Active'), findsOneWidget);
        expect(find.text('Visible to customers'), findsOneWidget);
        expect(updates, 2);
        expect(reads, 3);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
