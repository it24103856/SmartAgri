import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agriculture_flutter/core/widgets/profile_avatar.dart';
import 'package:agriculture_flutter/features/auth/data/services/profile_photo.dart';
import 'package:agriculture_flutter/features/auth/data/services/auth_service.dart';
import 'package:agriculture_flutter/features/auth/presentation/screens/register_screen.dart';
import 'package:agriculture_flutter/features/home/data/catalog_service.dart';
import 'package:agriculture_flutter/features/home/presentation/screens/customer_home_screen.dart';

final photo = ProfilePhoto(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=',
  ),
  'profile.png',
);
CatalogData catalog() => CatalogData.fromJson({
  'fullName': 'Amali',
  'profileImageUrl': '/uploads/profiles/old.png',
  'categories': [],
  'products': [],
});

void main() {
  testWidgets('registration shows optional picker, preview and remove action', (
    tester,
  ) async {
    var picks = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: RegisterScreen(
          pickPhoto: () async {
            picks++;
            return photo;
          },
        ),
      ),
    );
    expect(
      tester.widget<ProfileAvatar>(find.byType(ProfileAvatar)).bytes,
      isNull,
    );
    await tester.tap(find.text('Add profile photo (optional)'));
    await tester.pumpAndSettle();
    expect(picks, 1);
    expect(
      tester.widget<ProfileAvatar>(find.byType(ProfileAvatar)).bytes,
      photo.bytes,
    );
    await tester.tap(find.text('Remove photo'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<ProfileAvatar>(find.byType(ProfileAvatar)).bytes,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile update changes avatar in profile and home', (
    tester,
  ) async {
    var uploads = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: CustomerHomeScreen(
          fullName: 'Amali',
          loadCatalog: () async => catalog(),
          pickPhoto: () async => photo,
          uploadPhoto: (selected) async {
            expect(selected, same(photo));
            uploads++;
            return '/uploads/profiles/new.png';
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<ProfileAvatar>(find.byType(ProfileAvatar)).url,
      endsWith('/old.png'),
    );
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change profile photo'));
    await tester.pumpAndSettle();
    expect(uploads, 1);
    expect(
      tester.widget<ProfileAvatar>(find.byType(ProfileAvatar)).url,
      endsWith('/new.png'),
    );
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<ProfileAvatar>(find.byType(ProfileAvatar)).url,
      endsWith('/new.png'),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed upload preserves previous photo and allows retry', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CustomerHomeScreen(
          fullName: 'Amali',
          loadCatalog: () async => catalog(),
          pickPhoto: () async => photo,
          uploadPhoto: (_) async => throw AuthException('Upload failed'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change profile photo'));
    await tester.pumpAndSettle();
    expect(find.text('Upload failed'), findsOneWidget);
    expect(
      tester.widget<ProfileAvatar>(find.byType(ProfileAvatar)).url,
      endsWith('/old.png'),
    );
    expect(find.text('Change profile photo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
