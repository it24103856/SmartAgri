import 'package:flutter/material.dart';
import '../../core/theme/theme_controller.dart';

class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.mode,
      builder: (context, mode, child) {
        final isDark = mode == ThemeMode.dark;

        return PopupMenuButton<ThemeMode>(
          tooltip: 'Choose theme',
          initialValue: mode,
          onSelected: (selectedMode) =>
              ThemeController.mode.value = selectedMode,
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: ThemeMode.light,
              child: ListTile(
                leading: Icon(Icons.light_mode_outlined),
                title: Text('Light'),
              ),
            ),
            PopupMenuItem(
              value: ThemeMode.dark,
              child: ListTile(
                leading: Icon(Icons.dark_mode_outlined),
                title: Text('Dark'),
              ),
            ),
          ],
          child: Icon(
            isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        );
      },
    );
  }
}
