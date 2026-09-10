import 'package:flutter_test/flutter_test.dart';
import 'package:agriculture_flutter/main.dart';
import 'package:agriculture_flutter/splash_screen.dart';
import 'package:agriculture_flutter/onboarding_screen.dart';

void main() {
  testWidgets('launches splash and advances to onboarding', (tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.byType(SplashScreen), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.byType(SplashScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });
}