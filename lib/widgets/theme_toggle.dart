import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/providers/theme_provider.dart';

/// Inline toggle chip that switches between light and dark themes.
class ThemeToggle extends StatelessWidget {
  const ThemeToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProv = context.watch<ThemeProvider>();
    return Tooltip(
      message: themeProv.isDark ? 'Light' : 'Dark',
      child: IconButton(
        onPressed: () => themeProv.toggle(),
        icon: Icon(
          themeProv.isDark
              ? Icons.light_mode_outlined
              : Icons.dark_mode_outlined,
        ),
      ),
    );
  }
}
