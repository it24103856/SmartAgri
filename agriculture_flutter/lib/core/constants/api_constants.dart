class ApiConstants {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://smartagri-api-5mkz.onrender.com/api',
  );

  static String? mediaUrl(String? path) {
    final value = path?.trim();
    if (value == null || value.isEmpty) return null;

    final uri = Uri.tryParse(value);
    if (uri == null) return null;
    if (uri.hasScheme) {
      return uri.scheme == 'http' || uri.scheme == 'https' ? value : null;
    }

    return Uri.parse(
      baseUrl,
    ).resolve('/${value.replaceFirst(RegExp(r'^/+'), '')}').toString();
  }

  static const String login = '/auth/login';
  static const String register = '/auth/register';
}
