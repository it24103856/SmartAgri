import 'package:agriculture_flutter/core/network/api_client.dart';
import 'package:agriculture_flutter/features/farmer/data/services/package_service.dart';
import 'package:agriculture_flutter/features/farmer/presentation/screens/packages_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('successful bookings refresh an already open My bookings tab', (
    tester,
  ) async {
    final dio = ApiClient.instance.dio;
    final original = List<Interceptor>.of(dio.interceptors);
    addTearDown(() {
      dio.interceptors
        ..clear()
        ..addAll(original);
    });
    final bookings = <Map<String, dynamic>>[];
    var bookingReads = 0;
    dio.interceptors
      ..clear()
      ..add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            Object data = <Object>[];
            if (request.path == '/farmer-packages/bookings') {
              if (request.method == 'POST') {
                final booking = <String, dynamic>{
                  'id': bookings.length + 1,
                  'packageId': 1,
                  'packageName': 'Field preparation',
                  'category': 'MACHINERY',
                  'calculatedQuantity': 2,
                  'totalPrice': 400,
                  'status': 'PENDING',
                  'createdAt': '2026-09-30T10:00:00Z',
                  'farmName': 'My farm',
                  'serviceDate': '2026-10-01',
                };
                bookings.add(booking);
                data = booking;
              } else {
                bookingReads++;
                data = List.of(bookings);
              }
            }
            handler.resolve(
              Response(requestOptions: request, statusCode: 200, data: data),
            );
          },
        ),
      );

    await tester.pumpWidget(const MaterialApp(home: PackagesScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('My bookings'));
    await tester.pumpAndSettle();
    expect(find.text('You have not booked anything yet.'), findsOneWidget);
    final readsBeforeBooking = bookingReads;

    // The shared service is also used by the dashboard booking sheet.
    final bookingRequest = PackageService.instance.book(
      packageId: 1,
      farmId: 1,
      serviceDate: '2026-10-01',
      landSizeAcres: 2,
    );
    await tester.pumpAndSettle();
    await bookingRequest;
    expect(bookingReads, greaterThan(readsBeforeBooking));
    expect(find.text('Field preparation'), findsOneWidget);
    expect(find.text('Booking #1'), findsOneWidget);
    expect(find.text('You have not booked anything yet.'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    final readsAfterDispose = bookingReads;
    final laterBookingRequest = PackageService.instance.book(
      packageId: 1,
      farmId: 1,
      serviceDate: '2026-10-01',
      landSizeAcres: 2,
    );
    await tester.pumpAndSettle();
    await laterBookingRequest;
    expect(bookingReads, readsAfterDispose);
    expect(tester.takeException(), isNull);
  });
}
