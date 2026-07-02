import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/providers/theme_provider.dart';

/// Inline toggle chip that switches between light and dark themes.
///
/// Uses [ThemeProvider.isDark] (the EFFECTIVE dark state) so the icon
/// matches what the user actually sees — even when the theme mode is
/// `ThemeMode.system` and the platform is in dark mode.
class ThemeToggle extends StatelessWidget {
  const ThemeToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProv = context.watch<ThemeProvider>();
    final dark = themeProv.isDark;
    // Show the icon of the theme the user will SWITCH TO on tap:
    //   - if currently dark → show sun (tap to switch to light)
    //   - if currently light → show moon (tap to switch to dark)
    return Tooltip(
      message: dark ? 'Switch to light' : 'Switch to dark',
      child: IconButton(
        onPressed: () => themeProv.toggle(),
        icon: Icon(
          dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
        ),
      ),
    );
  }
}
