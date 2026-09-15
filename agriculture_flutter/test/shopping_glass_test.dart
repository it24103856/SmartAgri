import 'package:agriculture_flutter/core/network/api_client.dart';
import 'package:agriculture_flutter/core/theme/app_theme.dart';
import 'package:agriculture_flutter/features/cart/presentation/cart_screen.dart';
import 'package:agriculture_flutter/features/products/presentation/screens/product_details_screen.dart';
import 'package:agriculture_flutter/features/products/presentation/screens/customer_home_screen.dart';
import 'package:agriculture_flutter/features/products/presentation/screens/products_screen.dart';
import 'package:agriculture_flutter/shared/widgets/catalog_common.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  var quantity = 1;
  late Interceptor fixture;
  setUp(() {
    quantity = 1;
    fixture = InterceptorsWrapper(
      onRequest: (request, handler) {
        if (request.method == 'PUT') quantity = request.data['quantity'] as int;
        if (request.method == 'DELETE') quantity = 0;
        final data = request.path.startsWith('/catalog/')
            ? <String, dynamic>{
                'id': 1,
                'categoryId': 1,
                'name': 'Fresh Avocado',
                'categoryName': 'Fruit',
                'description': 'Fresh produce from local growers.',
                'price': 350,
                'unit': 'kg',
                'stockQuantity': 5,
                'imageUrls': <String>[],
              }
            : <String, dynamic>{
                'items': [
                  if (quantity > 0)
                    {
                      'productId': 1,
                      'quantity': quantity,
                      'stockQuantity': 5,
                      'name': 'Fresh Avocado',
                      'unit': 'kg',
                      'imageUrl': null,
                      'unitPrice': 350,
                      'lineTotal': 350 * quantity,
                      'available': true,
                    },
                ],
                'subtotal': 350 * quantity,
                'canCheckout': quantity > 0,
              };
        final Object response = request.path == '/catalog/categories'
            ? [
                {'id': 1, 'name': 'Fruit', 'productCount': 1, 'imageUrl': null},
              ]
            : request.path == '/catalog/products'
            ? {
                'items': [data],
                'totalCount': 1,
                'page': 1,
                'pageSize': 12,
              }
            : data;
        handler.resolve(
          Response(requestOptions: request, statusCode: 200, data: response),
        );
      },
    );
    ApiClient.instance.dio.interceptors.insert(0, fixture);
  });
  tearDown(() => ApiClient.instance.dio.interceptors.remove(fixture));

  for (final dark in [false, true]) {
    testWidgets(
      'home and product list show glass in ${dark ? 'dark' : 'light'} mode',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final theme = dark ? AppTheme.darkTheme() : AppTheme.lightTheme();
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: const CustomerHomeScreen(fullName: 'Minsara'),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('AgriLink'), findsOneWidget);
        expect(find.text('Shop now'), findsOneWidget);
        expect(find.byType(GlassCatalogBackground), findsOneWidget);
        expect(find.byType(GlassCatalogCard), findsWidgets);
        await tester.tap(find.text('Shop now'));
        await tester.pumpAndSettle();
        expect(find.byType(ProductsScreen), findsOneWidget);
        expect(find.text('Fresh Avocado'), findsOneWidget);
        expect(find.byType(GlassCatalogCard), findsOneWidget);
        await tester.tap(find.text('Fresh Avocado'));
        await tester.pumpAndSettle();
        expect(find.byType(ProductDetailsScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      'shopping views render at phone width in ${dark ? 'dark' : 'light'} mode',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final theme = dark ? AppTheme.darkTheme() : AppTheme.lightTheme();
        await tester.pumpWidget(
          MaterialApp(theme: theme, home: const CartScreen()),
        );
        await tester.pumpAndSettle();
        expect(find.text('Fresh Avocado'), findsOneWidget);
        await tester.tap(find.byIcon(Icons.add_rounded));
        await tester.pumpAndSettle();
        expect(quantity, 2);
        expect(find.text('Rs. 700.00'), findsWidgets);
        await tester.tap(find.text('Remove'));
        await tester.pumpAndSettle();
        expect(find.text('Your cart is empty.'), findsOneWidget);
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: const ProductDetailsScreen(productId: 1),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Fresh Avocado'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.byTooltip('Increase quantity'),
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.byTooltip('Increase quantity'));
        await tester.pumpAndSettle();
        expect(find.text('Rs. 700.00'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
