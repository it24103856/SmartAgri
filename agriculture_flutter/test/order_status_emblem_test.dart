import 'package:agriculture_flutter/shared/widgets/order_status_emblem.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('confirmed changes to cancelled with stable dimensions', (
    tester,
  ) async {
    final status = ValueNotifier('Confirmed');
    addTearDown(status.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ValueListenableBuilder<String>(
              valueListenable: status,
              builder: (_, value, child) => OrderStatusEmblem(status: value),
            ),
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    final initialSize = tester.getSize(find.byType(OrderStatusEmblem));
    status.value = 'Cancelled';
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_rounded), findsNothing);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    expect(tester.getSize(find.byType(OrderStatusEmblem)), initialSize);
    final center = tester
        .widgetList<Container>(find.byType(Container))
        .where(
          (container) =>
              container.decoration is BoxDecoration &&
              (container.decoration as BoxDecoration).color ==
                  const Color(0xFFC94343),
        );
    expect(center, hasLength(1));
    expect(tester.takeException(), isNull);
  });
}
