import 'package:agriculture_flutter/core/theme/theme_controller.dart';
import 'package:agriculture_flutter/shared/widgets/theme_toggle_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => ThemeController.mode.value = ThemeMode.light);

  testWidgets('tap and directional swipes change the app theme', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: ThemeToggleButton())),
      ),
    );
    final toggle = find.byType(ThemeToggleButton);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(ThemeController.mode.value, ThemeMode.dark);
    await tester.drag(toggle, const Offset(60, 0));
    await tester.pumpAndSettle();
    expect(ThemeController.mode.value, ThemeMode.light);
    await tester.drag(toggle, const Offset(-60, 0));
    await tester.pumpAndSettle();
    expect(ThemeController.mode.value, ThemeMode.dark);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion switches immediately and exposes state', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(body: ThemeToggleButton()),
        ),
      ),
    );
    ThemeController.mode.value = ThemeMode.dark;
    await tester.pump();
    expect(ThemeController.mode.value, ThemeMode.dark);
    expect(find.bySemanticsLabel('Dark mode'), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}

