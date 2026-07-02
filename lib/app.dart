import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_colors.dart';
import 'core/providers/locale_provider.dart';
import 'core/providers/theme_provider.dart';
import 'core/providers/user_provider.dart';
import 'features/auth/username_screen.dart';
import 'features/home_shell.dart';

/// Root MaterialApp. Wires up theme, locale, RTL directionality, and routes.
///
/// NOTE: The Saudi Riyal SYMBOL is rendered as an SVG icon
/// (`assets/icons/sar_symbol.svg`) by [CurrencyDisplay] — we don't need
/// any custom font registration here because SVG renders identically on
/// every platform.
class BazaarApp extends StatelessWidget {
  const BazaarApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProv = context.watch<ThemeProvider>();
    final localeProv = context.watch<LocaleProvider>();
    final userProv = context.watch<UserProvider>();

    final light = _buildTheme(Brightness.light);
    final dark = _buildTheme(Brightness.dark);

    return MaterialApp(
      title: 'Bazaar',
      debugShowCheckedModeBanner: false,
      theme: light,
      darkTheme: dark,
      themeMode: themeProv.themeMode,
      locale: localeProv.locale,
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        // Track the platform brightness so ThemeProvider.isDark resolves
        // correctly when the user is on ThemeMode.system. We read it here
        // (inside builder) because MediaQuery is only available below
        // MaterialApp, not above it.
        final brightness = MediaQuery.platformBrightnessOf(context);
        // Defer the call to after the current build frame to avoid
        // notifyListeners() during build.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          themeProv.updatePlatformBrightness(brightness);
        });
        // Apply RTL/LTR at the root so every screen inherits it.
        return Directionality(
          textDirection: localeProv.textDirection,
          child: child!,
        );
      },
      home: userProv.hasUser ? const HomeShell() : const UsernameScreen(),
      routes: {
        '/home': (_) => const HomeShell(),
        '/username': (_) => const UsernameScreen(),
      },
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
      onPrimary: isDark ? AppColors.darkOnPrimary : AppColors.lightOnPrimary,
      secondary: isDark ? AppColors.darkAccent : AppColors.lightAccent,
      onSecondary:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      surface: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      onSurface: isDark ? AppColors.darkText : AppColors.lightText,
      error: Colors.red,
      onError: Colors.white,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );

    return base.copyWith(
      textTheme: GoogleFonts.notoSansTextTheme(base.textTheme).copyWith(
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 1,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        filled: true,
        fillColor: scheme.surface,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
