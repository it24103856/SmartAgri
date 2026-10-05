import 'package:agriculture_flutter/core/network/api_client.dart';
import 'package:agriculture_flutter/features/farmer/presentation/screens/farmer_ai_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'catalog supplies exclusion choices and a single result renders',
    (tester) async {
      final dio = ApiClient.instance.dio;
      final original = List<Interceptor>.of(dio.interceptors);
      dio.interceptors.clear();
      addTearDown(() {
        dio.interceptors.clear();
        dio.interceptors.addAll(original);
      });
      Map<String, dynamic>? submitted;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            dynamic body;
            if (request.path == '/AI/crop-catalog') {
              body = {
                'crops': [
                  {'id': 'tomato', 'name': 'Tomato'},
                  {'id': 'cabbage', 'name': 'Cabbage'},
                ],
              };
            } else if (request.path == '/AI/analyze-farm') {
              submitted = Map<String, dynamic>.from(request.data as Map);
              body = {
                'farmName': 'Test farm',
                'status': 'COMPLETED',
                'result': {
                  'recommendations': [
                    {
                      'crop_id': 'cabbage',
                      'name': 'Cabbage recommendation',
                      'suitability': 'CONDITIONAL',
                      'reasons': ['Soil pH=6.2 matches'],
                      'checks_needed': [],
                    },
                  ],
                  'tool_results': {
                    'carrot': {
                      'name': 'Carrot',
                      'eligible': false,
                      'suitability': 'INSUFFICIENT_EVIDENCE',
                      'conflicts': [],
                      'checks_needed': ['No climate bounds'],
                    },
                  },
                },
              };
            } else {
              body = [
                {
                  'id': 1,
                  'farmerId': 1,
                  'name': 'Test farm',
                  'totalArea': 1,
                  'soilType': 'loam',
                  'irrigationType': 'drip',
                  'status': 'ACTIVE',
                  'createdAt': '2026-10-05T00:00:00Z',
                },
              ];
            }
            handler.resolve(
              Response(requestOptions: request, statusCode: 200, data: body),
            );
          },
        ),
      );
      await tester.pumpWidget(const MaterialApp(home: FarmerAiScreen()));
      await tester.pumpAndSettle();
      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text('Tomato'),
        400,
        scrollable: scrollable,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tomato'));
      await tester.pump();
      await tester.scrollUntilVisible(
        find.text('Analyze farm'),
        300,
        scrollable: scrollable,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Analyze farm'));
      await tester.pumpAndSettle();
      expect(submitted?['excludedCropIds'], ['tomato']);
      await tester.scrollUntilVisible(
        find.text('Cabbage recommendation'),
        300,
        scrollable: scrollable,
      );
      expect(find.text('Cabbage recommendation'), findsOneWidget);
      expect(find.textContaining('Soil pH=6.2 matches'), findsOneWidget);
      expect(find.text('Carrot: INSUFFICIENT_EVIDENCE'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
