import 'package:agriculture_flutter/core/constants/api_constants.dart';
import 'package:agriculture_flutter/core/constants/api_endpoints.dart';
import 'package:agriculture_flutter/features/home/data/catalog_service.dart';
import 'package:agriculture_flutter/shared/widgets/catalog_common.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('API base and endpoint composition contain exactly one api prefix', () {
    final base = Uri.parse(ApiConstants.baseUrl);
    expect(base.path.replaceFirst(RegExp(r'/+$'), ''), '/api');
    expect(ApiEndpoints.baseUrl, ApiConstants.baseUrl);
    final options = BaseOptions(baseUrl: ApiConstants.baseUrl);
    for (final endpoint in [
      '/auth/login',
      '/catalog/products',
      '/AI/crop-catalog',
    ]) {
      final uri = Options().compose(options, endpoint).uri;
      expect(uri.path, '/api$endpoint');
      expect(uri.origin, base.origin);
    }
  });

  test('absolute Supabase media URLs and query strings remain unchanged', () {
    const url =
        'https://example.supabase.co/storage/v1/object/public/products/photo.jpg?version=1';
    expect(ApiConstants.mediaUrl(url), url);
    expect(catalogImageUrl(url), url);
    expect(const CatalogImage(url).url, url);
  });

  test('relative media resolves against backend origin, never under api', () {
    final expected =
        '${Uri.parse(ApiConstants.baseUrl).origin}/uploads/products/photo.jpg';
    for (final path in [
      'uploads/products/photo.jpg',
      '/uploads/products/photo.jpg',
    ]) {
      expect(ApiConstants.mediaUrl(path), expected);
      expect(catalogImageUrl(path), expected);
      expect(CatalogImage(path).url, expected);
    }
  });

  test(
    'empty, malformed and unsupported media URLs use existing fallbacks',
    () {
      for (final path in [
        null,
        '',
        ' ',
        'file:///tmp/photo.jpg',
        'javascript:alert(1)',
        'http://[',
      ]) {
        expect(ApiConstants.mediaUrl(path), isNull);
      }
    },
  );
}
