import 'package:agriculture_flutter/core/network/api_client.dart';
import 'package:agriculture_flutter/core/theme/app_theme.dart';
import 'package:agriculture_flutter/features/smart_basket/presentation/smart_basket_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Interceptor fixture;
  late Map<String, dynamic> basket;
  Map<String, dynamic>? created;
  Map<String, dynamic>? review;

  setUp(() {
    created = null;
    review = null;
    basket = {
      'id': 'basket-1',
      'version': 'version-1',
      'objective': 'Apple and gowa',
      'budget': null,
      'status': 'AwaitingCustomerReview',
      'unavailableItems': [
        {'requestedName': 'gowa', 'reason': 'not_available'},
      ],
      'items': [
        {
          'productId': 1,
          'productName': 'Apple',
          'unit': 'kg',
          'unitPrice': 350,
          'quantity': 1,
        },
      ],
    };
    fixture = InterceptorsWrapper(
      onRequest: (request, handler) {
        Object data;
        if (request.path == '/catalog/categories') {
          data = [
            {'id': 1, 'name': 'Fruit'},
          ];
        } else if (request.method == 'POST') {
          created = Map<String, dynamic>.from(request.data as Map);
          data = {'id': 'basket-1'};
        } else if (request.path.endsWith('/addable-products')) {
          data = {
            'version': 'version-1',
            'items': [
              {
                'productId': 2,
                'productName': 'Orange',
                'unit': 'kg',
                'unitPrice': 500,
                'stockQuantity': 10,
              },
            ],
          };
        } else if (request.method == 'PUT') {
          review = Map<String, dynamic>.from(request.data as Map);
          data = basket;
        } else if (request.path == '/customer-smart-baskets') {
          data = {'items': [], 'totalCount': 0};
        } else {
          data = basket;
        }
        handler.resolve(
          Response(requestOptions: request, statusCode: 200, data: data),
        );
      },
    );
    ApiClient.instance.dio.interceptors.insert(0, fixture);
  });

  tearDown(() => ApiClient.instance.dio.interceptors.remove(fixture));

  for (final budget in [null, '6000']) {
    testWidgets('creates a shopping list with budget $budget', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme(),
          home: const SmartBasketScreen(),
        ),
      );
      await tester.pumpAndSettle();
      if (budget != null) {
        await tester.enterText(find.byType(TextFormField).first, budget);
      }
      await tester.enterText(find.byType(TextFormField).last, 'Rice');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Create basket'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create basket'));
      await tester.pumpAndSettle();
      expect(created?['budget'], budget == null ? isNull : 6000);
      expect(created?['objective'], 'Rice');
      expect(find.byType(SmartBasketDetailScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('supplied invalid budget is not treated as absent', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SmartBasketScreen()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '0');
    await tester.enterText(find.byType(TextFormField).last, 'Rice');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Create basket'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create basket'));
    await tester.pumpAndSettle();
    expect(created, isNull);
    expect(find.textContaining('with up to 2 decimals'), findsOneWidget);
  });

  testWidgets('a supplied budget still prevents an over-budget review', (
    tester,
  ) async {
    basket['budget'] = 300;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme(),
        home: const SmartBasketDetailScreen(id: 'basket-1'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Submit for admin approval'),
      200,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Submit for admin approval'),
          )
          .onPressed,
      isNull,
    );
    expect(find.text('This basket exceeds your budget.'), findsOneWidget);
    expect(review, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fallback basket explains how it was prepared', (tester) async {
    basket['generationMode'] = 'catalog_fallback';
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme(),
        home: const SmartBasketDetailScreen(id: 'basket-1'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.textContaining('Prepared directly from your shopping list'),
      150,
    );
    expect(find.textContaining('while AI was unavailable'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unsupported fallback request displays retry guidance', (
    tester,
  ) async {
    basket['status'] = 'Failed';
    basket['items'] = [];
    basket['unavailableItems'] = [];
    basket['customerMessage'] =
        'AI is temporarily unavailable. Please use a simple shopping list.';
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme(),
        home: const SmartBasketDetailScreen(id: 'basket-1'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text(basket['customerMessage'] as String),
      150,
    );
    expect(find.text(basket['customerMessage'] as String), findsOneWidget);
    expect(find.text('Submit for admin approval'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final dark in [false, true]) {
    testWidgets(
      'partial basket can add and submit without budget in dark=$dark',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? AppTheme.darkTheme() : AppTheme.lightTheme(),
            home: const SmartBasketDetailScreen(id: 'basket-1'),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('No budget limit'), findsOneWidget);
        await tester.scrollUntilVisible(find.text('Unavailable items'), 150);
        expect(find.textContaining('gowa - Not available'), findsOneWidget);
        await tester.scrollUntilVisible(find.text('Add products'), 150);
        await tester.tap(find.text('Add products'));
        await tester.pumpAndSettle();
        expect(find.text('No budget limit'), findsOneWidget);
        await tester.tap(find.text('Orange'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Submit for admin approval'),
          200,
        );
        await tester.tap(find.text('Submit for admin approval'));
        await tester.pumpAndSettle();
        expect(review?['submitForApproval'], true);
        expect(review?['items'], [
          {'productId': 1, 'quantity': 1},
          {'productId': 2, 'quantity': 1},
        ]);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('all unavailable shows names and cannot submit an empty basket', (
    tester,
  ) async {
    basket['status'] = 'Failed';
    basket['items'] = [];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme(),
        home: const SmartBasketDetailScreen(id: 'basket-1'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('These items are unavailable'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Unavailable items'), 150);
    expect(find.textContaining('gowa - Not available'), findsOneWidget);
    expect(find.text('Submit for admin approval'), findsNothing);
    expect(find.text('Continue to checkout'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
