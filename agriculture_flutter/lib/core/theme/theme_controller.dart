import 'package:flutter/material.dart';

class ThemeController {
  ThemeController._();

  static final mode = ValueNotifier<ThemeMode>(ThemeMode.light);

  static void toggle() {
    mode.value = mode.value == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
  }
}
