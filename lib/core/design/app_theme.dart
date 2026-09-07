import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

/// Builds the complete light and dark [ThemeData] for the app.
///
/// Unlike the v1 theme (which set only 8 of ~30 ColorScheme roles and left
/// the rest to Material's tonal defaults), every role here is derived from
/// the souk palette so containers, chips, sheets and nav bars all share the
/// same warm identity in both brightnesses.
abstract final class AppTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final c = dark
        ? const _DarkTokens()
        : const _LightTokens(); // swappable token view of AppColors

    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.gold,
      onPrimary: c.onGold,
      primaryContainer: c.primaryContainer,
      onPrimaryContainer: c.onPrimaryContainer,
      secondary: c.success,
      onSecondary: c.onSuccess,
      secondaryContainer: c.successContainer,
      onSecondaryContainer: c.onSuccessContainer,
      tertiary: c.info,
      onTertiary: c.onInfo,
      tertiaryContainer: c.infoContainer,
      onTertiaryContainer: c.onInfoContainer,
      error: c.danger,
      onError: c.onDanger,
      errorContainer: c.dangerContainer,
      onErrorContainer: c.onDangerContainer,
      surface: c.surface,
      onSurface: c.text,
      surfaceContainerLowest: c.background,
      surfaceContainerLow: c.background,
      surfaceContainer: c.surface,
      surfaceContainerHigh: c.surfaceHigh,
      surfaceContainerHighest: c.surfaceHigh,
      onSurfaceVariant: c.textMuted,
      outline: c.border,
      outlineVariant: c.border,
      shadow: const Color(0xFF000000),
      scrim: const Color(0xB3000000),
      inverseSurface: dark ? const Color(0xFFF5F5F4) : const Color(0xFF1A1815),
      onInverseSurface: dark
          ? const Color(0xFF22211F)
          : const Color(0xFFEEEEED),
      inversePrimary: dark ? c.gold : AppColors.darkGold,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.background,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );

    final textTheme = AppTypography.textTheme(base.textTheme);

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        foregroundColor: c.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: c.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.gold, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.danger),
        ),
        filled: true,
        fillColor: c.surfaceHigh,
        hintStyle: textTheme.bodyMedium?.copyWith(color: c.textMuted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.gold,
          foregroundColor: c.onGold,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.gold,
          side: BorderSide(color: c.border),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: c.gold),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: dark ? AppColors.darkSurfaceHigh : AppColors.lightText,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: dark ? AppColors.darkText : AppColors.lightBackground,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: textTheme.titleLarge?.copyWith(color: c.text),
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: c.text),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: c.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        showDragHandle: true,
        dragHandleColor: c.border,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surface,
        indicatorColor: c.primaryContainer,
        surfaceTintColor: Colors.transparent,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? c.gold : c.textMuted,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelMedium!.copyWith(
            color: states.contains(WidgetState.selected) ? c.gold : c.textMuted,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.gold,
        foregroundColor: c.onGold,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return c.gold;
          return Colors.transparent;
        }),
        side: BorderSide(color: c.border, width: 1.6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      dividerTheme: DividerThemeData(color: c.border, thickness: 1, space: 1),
      listTileTheme: ListTileThemeData(
        iconColor: c.textMuted,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surfaceHigh,
        side: BorderSide(color: c.border),
        labelStyle: textTheme.labelMedium,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      ),
      expansionTileTheme: ExpansionTileThemeData(
        backgroundColor: c.surface,
        collapsedBackgroundColor: c.surface,
        iconColor: c.textMuted,
        collapsedIconColor: c.textMuted,
        shape: const Border(),
        collapsedShape: const Border(),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.gold,
        linearTrackColor: c.surfaceHigh,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? c.onGold : c.textMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? c.gold : c.surfaceHigh,
        ),
      ),
    );
  }
}

/// A brightness-specific view over [AppColors] so [_build] reads naturally.
abstract interface class _Tokens {
  Color get gold;
  Color get onGold;
  Color get primaryContainer;
  Color get onPrimaryContainer;
  Color get success;
  Color get onSuccess;
  Color get successContainer;
  Color get onSuccessContainer;
  Color get info;
  Color get onInfo;
  Color get infoContainer;
  Color get onInfoContainer;
  Color get danger;
  Color get onDanger;
  Color get dangerContainer;
  Color get onDangerContainer;
  Color get background;
  Color get surface;
  Color get surfaceHigh;
  Color get border;
  Color get text;
  Color get textMuted;
}

final class _DarkTokens implements _Tokens {
  const _DarkTokens();

  @override
  Color get gold => AppColors.darkGold;
  @override
  Color get onGold => AppColors.darkOnGold;
  @override
  Color get primaryContainer => const Color(0xFF3A3220);
  @override
  Color get onPrimaryContainer => const Color(0xFFEDDCA8);
  @override
  Color get success => AppColors.darkSuccess;
  @override
  Color get onSuccess => const Color(0xFF0E2917);
  @override
  Color get successContainer => const Color(0xFF1E3527);
  @override
  Color get onSuccessContainer => const Color(0xFFB7E3C6);
  @override
  Color get info => AppColors.darkInfo;
  @override
  Color get onInfo => const Color(0xFF0F2530);
  @override
  Color get infoContainer => const Color(0xFF1D323D);
  @override
  Color get onInfoContainer => const Color(0xFFBFDCEA);
  @override
  Color get danger => AppColors.darkDanger;
  @override
  Color get onDanger => AppColors.darkOnDanger;
  @override
  Color get dangerContainer => const Color(0xFF3A2320);
  @override
  Color get onDangerContainer => const Color(0xFFEFC4BE);
  @override
  Color get background => AppColors.darkBackground;
  @override
  Color get surface => AppColors.darkSurface;
  @override
  Color get surfaceHigh => AppColors.darkSurfaceHigh;
  @override
  Color get border => AppColors.darkBorder;
  @override
  Color get text => AppColors.darkText;
  @override
  Color get textMuted => AppColors.darkTextMuted;
}

final class _LightTokens implements _Tokens {
  const _LightTokens();

  @override
  Color get gold => AppColors.lightGold;
  @override
  Color get onGold => AppColors.lightOnGold;
  @override
  Color get primaryContainer => const Color(0xFFF1E8CE);
  @override
  Color get onPrimaryContainer => const Color(0xFF4A3D14);
  @override
  Color get success => AppColors.lightSuccess;
  @override
  Color get onSuccess => const Color(0xFFFFFFFF);
  @override
  Color get successContainer => const Color(0xFFDDEFE2);
  @override
  Color get onSuccessContainer => const Color(0xFF1D4A2E);
  @override
  Color get info => AppColors.lightInfo;
  @override
  Color get onInfo => const Color(0xFFFFFFFF);
  @override
  Color get infoContainer => const Color(0xFFDCE9F0);
  @override
  Color get onInfoContainer => const Color(0xFF1F3D4A);
  @override
  Color get danger => AppColors.lightDanger;
  @override
  Color get onDanger => AppColors.lightOnDanger;
  @override
  Color get dangerContainer => const Color(0xFFF3DDDA);
  @override
  Color get onDangerContainer => const Color(0xFF5C2620);
  @override
  Color get background => AppColors.lightBackground;
  @override
  Color get surface => AppColors.lightSurface;
  @override
  Color get surfaceHigh => AppColors.lightSurfaceHigh;
  @override
  Color get border => AppColors.lightBorder;
  @override
  Color get text => AppColors.lightText;
  @override
  Color get textMuted => AppColors.lightTextMuted;
}
