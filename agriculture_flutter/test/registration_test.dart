import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agriculture_flutter/features/auth/presentation/screens/register_screen.dart';

void main() {
  testWidgets(
    'province filters cities and changing it clears the selected city',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));
      final dropdowns = find.byType(DropdownButtonFormField<String>);
      DropdownButton<String> menu(int index) =>
          tester.widget<DropdownButton<String>>(
            find.descendant(
              of: dropdowns.at(index),
              matching: find.byType(DropdownButton<String>),
            ),
          );
      DropdownButtonFormField<String> city() =>
          tester.widget<DropdownButtonFormField<String>>(dropdowns.at(1));
      expect(city().onChanged, isNull);
      expect(menu(1).items, isEmpty);
      final province = tester.widget<DropdownButtonFormField<String>>(
        dropdowns.first,
      );
      expect(menu(0).items!.length, 9);
      province.onChanged!('Western');
      await tester.pumpAndSettle();
      expect(menu(1).items!.map((item) => item.value), contains('Colombo'));
      expect(
        menu(1).items!.map((item) => item.value),
        isNot(contains('Kandy')),
      );
      tester
          .state<FormFieldState<String>>(dropdowns.at(1))
          .didChange('Colombo');
      city().onChanged!('Colombo');
      await tester.pumpAndSettle();
      expect(
        tester.state<FormFieldState<String>>(dropdowns.at(1)).value,
        'Colombo',
      );
      province.onChanged!('Central');
      await tester.pumpAndSettle();
      expect(menu(1).items!.map((item) => item.value), contains('Kandy'));
      expect(
        menu(1).items!.map((item) => item.value),
        isNot(contains('Colombo')),
      );
      expect(
        tester.state<FormFieldState<String>>(dropdowns.at(1)).value,
        isNull,
      );
      expect(
        tester.state<FormFieldState<String>>(dropdowns.at(1)).validate(),
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'registration requires contact and location and validates phone',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));
      final form = tester.state<FormState>(find.byType(Form));
      expect(form.validate(), isFalse);
      await tester.pump();
      for (final label in ['Telephone number', 'Address', 'City', 'Province']) {
        expect(find.text('$label is required'), findsOneWidget);
      }
      for (final entry in {
        'phone': 'invalid',
        'address': '12 Main Street',
      }.entries) {
        await tester.enterText(find.byKey(ValueKey(entry.key)), entry.value);
      }
      form.validate();
      await tester.pump();
      expect(find.text('Enter a valid telephone number'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('phone')),
        '+94 77 123 4567',
      );
      form.validate();
      await tester.pump();
      expect(find.text('Enter a valid telephone number'), findsNothing);
      for (final label in ['Telephone number', 'Address']) {
        expect(find.text('$label is required'), findsNothing);
      }
      expect(tester.takeException(), isNull);
    },
  );
}
