import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  static ThemeData lightTheme() => _build(Brightness.light);

  static ThemeData darkTheme() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final background = isDark
        ? const Color(0xFF080D0A)
        : const Color(0xFFF7F9F8);

    final colors =
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF3B6E52),
          brightness: brightness,
        ).copyWith(
          primary: isDark ? const Color(0xFFA4D3AF) : const Color(0xFF3B6E52),

          onPrimary: isDark ? const Color(0xFF163422) : Colors.white,

          primaryContainer: isDark
              ? const Color(0xFF14251A)
              : const Color(0xFFEAF2EA),

          onPrimaryContainer: isDark
              ? const Color(0xFFD6EDDA)
              : const Color(0xFF2D4B3E),

          surface: isDark ? const Color(0xFF101812) : Colors.white,

          surfaceContainerHighest: isDark
              ? const Color(0xFF1B2B20)
              : const Color(0xFFDDECDD),

          onSurface: isDark ? const Color(0xFFE8F0EA) : const Color(0xFF2D4B3E),

          onSurfaceVariant: isDark
              ? const Color(0xFFB2C3B7)
              : const Color(0xFF68786D),

          outlineVariant: isDark
              ? const Color(0xFF34483A)
              : const Color(0xFFDFE8E0),

          tertiary: isDark ? const Color(0xFFF0C28A) : const Color(0xFF97551F),

          error: isDark ? const Color(0xFFFFB4AB) : const Color(0xFFB84646),
        );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colors,
      scaffoldBackgroundColor: background,
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: colors.onSurface,
        displayColor: colors.onSurface,
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: colors.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surface,
        hintStyle: TextStyle(color: colors.onSurfaceVariant),
        prefixIconColor: colors.onSurfaceVariant,
        suffixIconColor: colors.onSurfaceVariant,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: colors.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: colors.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: colors.primary, width: 1.5),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.surface,
        indicatorColor: colors.primaryContainer,
        elevation: 0,
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),

      dividerTheme: DividerThemeData(color: colors.outlineVariant),
    );
  }
}
