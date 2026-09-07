import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/currencies.dart';
import '../services/on_device_llm.dart';
import '../services/scraper_service.dart';
import '../services/scraping_config.dart';

// ── Persistence keys ───────────────────────────────────────────────────────
const _kThemeMode = 'prefs.theme_mode';
const _kLocale = 'prefs.locale';
const _kCurrency = 'prefs.currency';
const _kUsername = 'prefs.username';

/// SharedPreferences instance (loaded once in main() before runApp).
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(),
);

// ── Theme ──────────────────────────────────────────────────────────────────
class ThemeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final raw = ref.read(sharedPreferencesProvider).getString(_kThemeMode);
    return ThemeMode.values.firstWhere(
      (m) => m.name == raw,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await ref.read(sharedPreferencesProvider).setString(_kThemeMode, mode.name);
  }
}

final themeProvider = NotifierProvider<ThemeNotifier, ThemeMode>(
  ThemeNotifier.new,
);

// ── Locale ─────────────────────────────────────────────────────────────────
/// Null = follow the system locale.
class LocaleNotifier extends Notifier<Locale?> {
  @override
  Locale? build() {
    final raw = ref.read(sharedPreferencesProvider).getString(_kLocale);
    if (raw == null || raw.isEmpty) return null;
    return Locale(raw);
  }

  Future<void> set(Locale? locale) async {
    state = locale;
    final sp = ref.read(sharedPreferencesProvider);
    if (locale == null) {
      await sp.remove(_kLocale);
    } else {
      await sp.setString(_kLocale, locale.languageCode);
    }
  }

  /// Effective locale code ('en' when the system locale is unsupported).
  String get effectiveCode {
    final l = state ?? WidgetsBinding.instance.platformDispatcher.locale;
    return l.languageCode == 'ar' ? 'ar' : 'en';
  }

  bool get isRtl => effectiveCode == 'ar';
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale?>(
  LocaleNotifier.new,
);

// ── Currency ───────────────────────────────────────────────────────────────
class CurrencyNotifier extends Notifier<AppCurrency> {
  @override
  AppCurrency build() {
    final raw = ref.read(sharedPreferencesProvider).getString(_kCurrency);
    return currencyFromCode(raw ?? 'SAR');
  }

  Future<void> set(AppCurrency currency) async {
    state = currency;
    await ref
        .read(sharedPreferencesProvider)
        .setString(_kCurrency, currency.code);
  }
}

final currencyProvider = NotifierProvider<CurrencyNotifier, AppCurrency>(
  CurrencyNotifier.new,
);

// ── Local user identity ────────────────────────────────────────────────────
/// The local-only username. Null until onboarding completes.
class UserNotifier extends Notifier<String?> {
  @override
  String? build() => ref.read(sharedPreferencesProvider).getString(_kUsername);

  Future<void> set(String? name) async {
    state = name;
    final sp = ref.read(sharedPreferencesProvider);
    if (name == null || name.isEmpty) {
      await sp.remove(_kUsername);
    } else {
      await sp.setString(_kUsername, name);
    }
  }
}

final userProvider = NotifierProvider<UserNotifier, String?>(UserNotifier.new);

// ── Scraping / LLM config ──────────────────────────────────────────────────
class ScrapingConfigNotifier extends Notifier<ScrapingConfig> {
  @override
  ScrapingConfig build() => const ScrapingConfig();

  Future<void> load() async {
    state = await ScrapingConfig.load();
    // The scraper reads this snapshot — keep it in sync.
    _applyToScraper();
  }

  Future<void> update(ScrapingConfig config) async {
    state = config;
    await config.save();
    _applyToScraper();
  }

  void _applyToScraper() => ScraperService.instance.config = state;
}

final scrapingConfigProvider =
    NotifierProvider<ScrapingConfigNotifier, ScrapingConfig>(
      ScrapingConfigNotifier.new,
    );

/// Presence flags for the secrets (never the secrets themselves).
class KeyPresenceNotifier extends AsyncNotifier<KeyPresence> {
  @override
  Future<KeyPresence> build() => readKeyPresence();

  Future<void> refresh() async {
    state = await AsyncValue.guard(readKeyPresence);
  }
}

final keyPresenceProvider =
    AsyncNotifierProvider<KeyPresenceNotifier, KeyPresence>(
      KeyPresenceNotifier.new,
    );

/// Kick off on-device model loading in the background (optional setting).
final onDeviceAutoloadProvider = Provider<void>((ref) {
  final config = ref.watch(scrapingConfigProvider);
  if (!config.autoLoadOnDevice) return;
  Future(() async {
    try {
      await OnDeviceLlm.instance.load();
    } catch (_) {
      // Autoload is best-effort; the pipeline surfaces real errors.
    }
  });
});
