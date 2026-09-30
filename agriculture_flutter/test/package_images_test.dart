import 'package:agriculture_flutter/features/farmer/data/models/package_models.dart';
import 'package:agriculture_flutter/features/farmer/presentation/widgets/package_images.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Package package({List<String>? images}) => Package.fromJson({
  'id': 1,
  'name': 'Land preparation',
  'description': 'Prepare the fields.',
  'category': 'MACHINERY',
  'baseRate': 200,
  'isActive': true,
  'imageUrls': ?images,
});

void main() {
  testWidgets('older packages without images retain their category icon', (
    tester,
  ) async {
    final data = package();
    expect(data.thumbnail, isNull);
    expect(data.rateLabel, 'Rs. 200.00 / acre');
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(height: 180, child: PackageCoverImage(package: data)),
      ),
    );
    expect(find.byIcon(Icons.agriculture_rounded), findsOneWidget);
  });

  testWidgets(
    'gallery keeps cover order and swipes even when images cannot load',
    (tester) async {
      final data = package(
        images: ['/uploads/packages/cover.jpg', '/uploads/packages/second.jpg'],
      );
      expect(data.thumbnail, '/uploads/packages/cover.jpg');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PackageImageGallery(package: data)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('1 / 2 photos · Swipe to explore'), findsOneWidget);
      await tester.drag(find.byType(PageView), const Offset(-700, 0));
      await tester.pumpAndSettle();
      expect(find.text('2 / 2 photos · Swipe to explore'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
