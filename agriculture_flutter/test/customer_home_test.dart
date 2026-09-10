import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agriculture_flutter/features/home/data/catalog_service.dart';
import 'package:agriculture_flutter/features/home/presentation/screens/customer_home_screen.dart';

CatalogData fixture() => CatalogData.fromJson({
  'fullName': 'Amali Perera',
  'categories': [
    {'id': 1, 'name': 'Vegetables', 'imageUrl': null},
  ],
  'products': [
    {
      'id': 1,
      'name': 'Carrots',
      'categoryId': 1,
      'categoryName': 'Vegetables',
      'stockQuantity': 1,
      'price': 250,
      'unit': 'kg',
      'imageUrls': [],
    },
    {
      'id': 2,
      'name': 'Tomatoes',
      'categoryId': 1,
      'categoryName': 'Vegetables',
      'stockQuantity': 0,
      'price': 300,
      'unit': 'kg',
      'imageUrls': [],
    },
  ],
});

void main() {
  testWidgets(
    'loads real response fields, searches, limits stock and updates cart',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: CustomerHomeScreen(
            fullName: 'Customer',
            loadCatalog: () async => fixture(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Hi, Amali \u{1F44B}'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'carrots');
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Add'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Tomatoes'), findsNothing);
      await tester.dragUntilVisible(
        find.text('Add').hitTestable(),
        find.byType(ListView).first,
        const Offset(0, -180),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      expect(find.text('Stock limit'), findsOneWidget);
      await tester.tap(find.text('Cart'));
      await tester.pumpAndSettle();
      expect(find.text('Subtotal'), findsOneWidget);
      expect(find.text('LKR 250.00'), findsWidgets);
      await tester.tap(find.byTooltip('Remove Carrots'));
      await tester.pumpAndSettle();
      expect(find.text('Your cart is empty.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('shows loading and supports retry after a failed request', (
    tester,
  ) async {
    final pending = Completer<CatalogData>();
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: CustomerHomeScreen(
          fullName: 'Customer',
          loadCatalog: () {
            calls++;
            return calls == 1 ? pending.future : Future.value(fixture());
          },
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.completeError(const CatalogException('Connection failed'));
    await tester.pumpAndSettle();
    expect(find.text('Connection failed'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Hi, Amali \u{1F44B}'), findsOneWidget);
    expect(calls, 2);
    expect(tester.takeException(), isNull);
  });
}
