import 'package:agriculture_flutter/shared/widgets/customer_animated_nav_bar.dart';
import 'package:agriculture_flutter/shared/widgets/customer_create_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('create menu hides and restores the selected tab ball', (
    tester,
  ) async {
    for (var index = 0; index < 4; index++) {
      Future<void> showBar(bool menuOpen) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              bottomNavigationBar: CustomerAnimatedNavBar(
                selectedIndex: index,
                onSelected: (_) {},
                onCreate: () {},
                isCreateMenuOpen: menuOpen,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await showBar(false);
      expect(find.byKey(const ValueKey('selected-tab-ball')), findsOneWidget);
      await showBar(true);
      expect(find.byKey(const ValueKey('selected-tab-ball')), findsNothing);
      expect(
        find.text(['Home', 'Products', 'Cart', 'Profile'][index]),
        findsOneWidget,
      );
      await showBar(false);
      expect(find.byKey(const ValueKey('selected-tab-ball')), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('both action balls travel outward together before settling', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showCustomerCreateMenu(context),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    final camera = find.byIcon(Icons.photo_camera_outlined);
    final text = find.byIcon(Icons.edit_note_rounded);
    final startCamera = tester.getCenter(camera);
    final startText = tester.getCenter(text);
    await tester.pump(const Duration(milliseconds: 300));
    final midCamera = tester.getCenter(camera);
    final midText = tester.getCenter(text);
    expect(midCamera.dx, lessThan(startCamera.dx - 20));
    expect(midText.dx, greaterThan(startText.dx + 20));
    expect(midCamera.dy, lessThan(startCamera.dy - 40));
    expect(midText.dy, closeTo(midCamera.dy, 0.1));
    await tester.pumpAndSettle();
    expect(
      tester.getCenter(text).dx - tester.getCenter(camera).dx,
      closeTo(128, 0.1),
    );
    await tester.tap(find.byTooltip('Close create menu'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Camera'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('center action and all four tabs keep distinct callbacks', (
    tester,
  ) async {
    var selected = 0;
    var creates = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            bottomNavigationBar: CustomerAnimatedNavBar(
              selectedIndex: selected,
              onSelected: (index) => setState(() => selected = index),
              onCreate: () => creates++,
            ),
          ),
        ),
      ),
    );
    for (final entry in {
      'Products': 1,
      'Cart': 2,
      'Profile': 3,
      'Home': 0,
    }.entries) {
      await tester.tap(find.text(entry.key));
      await tester.pumpAndSettle();
      expect(selected, entry.value);
    }
    await tester.tap(find.byTooltip('Create'));
    expect(creates, 1);
    expect(selected, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('expanded menu selects camera or text and can close', (
    tester,
  ) async {
    CustomerCreateAction? action;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                action = await showCustomerCreateMenu(context);
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    for (final label in ['Camera', 'Write text', 'Close create menu']) {
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(label));
      await tester.pumpAndSettle();
      expect(
        action,
        label == 'Camera'
            ? CustomerCreateAction.camera
            : label == 'Write text'
            ? CustomerCreateAction.text
            : null,
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('editor keeps text and the question or post choice on return', (
    tester,
  ) async {
    final draft = CustomerDraft();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => CustomerComposerScreen(draft: draft),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      'Why are the leaves yellow?',
    );
    await tester.tap(find.text('Post'));
    await tester.pumpAndSettle();
    expect(find.text('Create a post'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Why are the leaves yellow?'), findsOneWidget);
    expect(draft.isQuestion, isFalse);
    expect(tester.takeException(), isNull);
  });
}
