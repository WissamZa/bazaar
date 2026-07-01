import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/llm_extractor.dart';
import '../services/secrets.dart';
import '../services/on_device_llm.dart';

/// Which strategy the scraper should use for product data extraction.
enum ExtractionStrategy {
  /// Tier 1 only — SearXNG → fetch first result → parse JSON-LD/OG meta.
  /// Zero cost, zero LLM, ~70% hit rate on Saudi e-com sites.
  schemaOnly,

  /// Tier 1 + Tier 2 — schema parse first, fall back to cloud LLM if it fails.
  /// Free with Gemini; small cost otherwise.
  schemaThenCloudLlm,

  /// Tier 1 + Tier 3 — schema parse, then on-device LLM fallback.
  /// Fully offline, no API key needed, but ~2 GB model download.
  schemaThenOnDevice,

  /// Tier 1 + Tier 2 + Tier 3 — try schema, then cloud, then on-device.
  schemaCloudOnDevice,

  /// Tier 2 only — go straight to cloud LLM (debug / testing).
  cloudLlmOnly,

  /// Tier 3 only — go straight to on-device LLM (debug / testing).
  onDeviceOnly,
}

extension ExtractionStrategyX on ExtractionStrategy {
  String get label => switch (this) {
        ExtractionStrategy.schemaOnly           => 'Schema only (fast, free)',
        ExtractionStrategy.schemaThenCloudLlm   => 'Schema → Cloud LLM',
        ExtractionStrategy.schemaThenOnDevice   => 'Schema → On-device LLM',
        ExtractionStrategy.schemaCloudOnDevice  => 'Schema → Cloud → On-device',
        ExtractionStrategy.cloudLlmOnly         => 'Cloud LLM only',
        ExtractionStrategy.onDeviceOnly         => 'On-device LLM only',
      };

  String get labelAr => switch (this) {
        ExtractionStrategy.schemaOnly           => 'البنية فقط (سريع ومجاني)',
        ExtractionStrategy.schemaThenCloudLlm   => 'البنية ← سحابة LLM',
        ExtractionStrategy.schemaThenOnDevice   => 'البنية ← LLM محلي',
        ExtractionStrategy.schemaCloudOnDevice  => 'البنية ← سحابة ← محلي',
        ExtractionStrategy.cloudLlmOnly         => 'سحابة LLM فقط',
        ExtractionStrategy.onDeviceOnly         => 'LLM محلي فقط',
      };

  String displayName(String locale) =>
      locale == 'ar' ? labelAr : label;

  bool get usesCloudLlm =>
      this == ExtractionStrategy.schemaThenCloudLlm ||
      this == ExtractionStrategy.schemaCloudOnDevice ||
      this == ExtractionStrategy.cloudLlmOnly;

  bool get usesOnDevice =>
      this == ExtractionStrategy.schemaThenOnDevice ||
      this == ExtractionStrategy.schemaCloudOnDevice ||
      this == ExtractionStrategy.onDeviceOnly;

  bool get usesSchema =>
      this != ExtractionStrategy.cloudLlmOnly &&
      this != ExtractionStrategy.onDeviceOnly;
}

/// Persisted scraping / LLM settings.
///
/// NON-SECRET fields live in SharedPreferences (strategy choice, provider,
/// model name). SECRET fields (API keys) live in [Secrets] (Keystore /
/// Keychain) — never here.
class ScrapingProvider extends ChangeNotifier {
  static const _kStrategy       = 'scraping.strategy';
  static const _kLlmProvider    = 'scraping.llm_provider';
  static const _kLlmModel       = 'scraping.llm_model';
  static const _kLlmBaseUrl     = 'scraping.llm_base_url';
  static const _kSearxngUrl     = 'scraping.searxng_url';
  static const _kAutoLoadOnDev  = 'scraping.autoload_on_device';

  ExtractionStrategy _strategy = ExtractionStrategy.schemaThenCloudLlm;
  LlmProvider _provider = LlmProvider.gemini;
  String _model = '';
  String _baseUrl = '';
  String _searxngUrl = 'https://cachyos-nitro.tail3d23b7.ts.net:8080';
  bool _autoLoadOnDevice = false;

  // Cached presence flags — we never hold the actual keys in memory long-term.
  bool _hasGeminiKey = false;
  bool _hasOpenAiKey = false;
  bool _hasGroqKey = false;
  bool _hasCerebrasKey = false;
  bool _hasOllamaBaseUrl = false;
  bool _hasOnDeviceModel = false;

  ExtractionStrategy get strategy => _strategy;
  LlmProvider get provider => _provider;
  String get model => _model;
  String get baseUrl => _baseUrl;
  String get searxngUrl => _searxngUrl;
  bool get autoLoadOnDevice => _autoLoadOnDevice;

  bool get hasGeminiKey => _hasGeminiKey;
  bool get hasOpenAiKey => _hasOpenAiKey;
  bool get hasGroqKey => _hasGroqKey;
  bool get hasCerebrasKey => _hasCerebrasKey;
  bool get hasOllamaBaseUrl => _hasOllamaBaseUrl;
  bool get hasOnDeviceModel => _hasOnDeviceModel;

  /// True if the current config is ready to actually use the LLM.
  /// Used by the settings UI to show a green check / red warning.
  bool get isConfigComplete {
    if (!_strategy.usesCloudLlm && !_strategy.usesOnDevice) return true;
    if (_strategy.usesCloudLlm) {
      switch (_provider) {
        case LlmProvider.gemini:   return _hasGeminiKey;
        case LlmProvider.openai:   return _hasOpenAiKey;
        case LlmProvider.groq:     return _hasGroqKey;
        case LlmProvider.cerebras: return _hasCerebrasKey;
        case LlmProvider.ollama:   return _hasOllamaBaseUrl;
      }
    }
    if (_strategy.usesOnDevice) return _hasOnDeviceModel;
    return false;
  }

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    _strategy = ExtractionStrategy.values.firstWhere(
      (e) => e.name == sp.getString(_kStrategy),
      orElse: () => ExtractionStrategy.schemaThenCloudLlm,
    );
    _provider = LlmProvider.values.firstWhere(
      (e) => e.name == sp.getString(_kLlmProvider),
      orElse: () => LlmProvider.gemini,
    );
    _model      = sp.getString(_kLlmModel)   ?? '';
    _baseUrl    = sp.getString(_kLlmBaseUrl) ?? '';
    _searxngUrl = sp.getString(_kSearxngUrl) ??
        'https://cachyos-nitro.tail3d23b7.ts.net:8080';
    _autoLoadOnDevice = sp.getBool(_kAutoLoadOnDev) ?? false;

    await _refreshKeyFlags();
    notifyListeners();
  }

  Future<void> setStrategy(ExtractionStrategy v) async {
    _strategy = v;
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kStrategy, v.name);
    notifyListeners();
  }

  Future<void> setProvider(LlmProvider v) async {
    _provider = v;
    // Reset model/baseUrl to provider defaults so user doesn't end up with
    // a mismatched (e.g. Gemini model on Groq endpoint).
    _model = '';
    _baseUrl = '';
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kLlmProvider, v.name);
    await sp.remove(_kLlmModel);
    await sp.remove(_kLlmBaseUrl);
    notifyListeners();
  }

  Future<void> setModel(String v) async {
    _model = v;
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kLlmModel, v);
    notifyListeners();
  }

  Future<void> setBaseUrl(String v) async {
    _baseUrl = v;
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kLlmBaseUrl, v);
    notifyListeners();
  }

  Future<void> setSearxngUrl(String v) async {
    _searxngUrl = v;
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kSearxngUrl, v);
    notifyListeners();
  }

  Future<void> setAutoLoadOnDevice(bool v) async {
    _autoLoadOnDevice = v;
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kAutoLoadOnDev, v);
    notifyListeners();
  }

  // ── API-key writers — write to Secrets, then refresh cached flags ──────
  Future<void> setGeminiKey(String? v) async {
    await Secrets.instance.setGeminiKey(v);
    await _refreshKeyFlags();
    notifyListeners();
  }

  Future<void> setOpenAiKey(String? v) async {
    await Secrets.instance.setOpenAiKey(v);
    await _refreshKeyFlags();
    notifyListeners();
  }

  Future<void> setGroqKey(String? v) async {
    await Secrets.instance.setGroqKey(v);
    await _refreshKeyFlags();
    notifyListeners();
  }

  Future<void> setCerebrasKey(String? v) async {
    await Secrets.instance.setCerebrasKey(v);
    await _refreshKeyFlags();
    notifyListeners();
  }

  Future<void> setOllamaBaseUrl(String? v) async {
    await Secrets.instance.setOllamaBaseUrl(v);
    await _refreshKeyFlags();
    notifyListeners();
  }

  /// Mark the on-device model as downloaded (called from settings UI after
  /// [OnDeviceLlm.downloadModel] succeeds).
  Future<void> markOnDeviceModelReady() async {
    await _refreshKeyFlags();
    notifyListeners();
  }

  Future<void> _refreshKeyFlags() async {
    _hasGeminiKey      = (await Secrets.instance.getGeminiKey())?.isNotEmpty ?? false;
    _hasOpenAiKey      = (await Secrets.instance.getOpenAiKey())?.isNotEmpty ?? false;
    _hasGroqKey        = (await Secrets.instance.getGroqKey())?.isNotEmpty ?? false;
    _hasCerebrasKey    = (await Secrets.instance.getCerebrasKey())?.isNotEmpty ?? false;
    _hasOllamaBaseUrl  = (await Secrets.instance.getOllamaBaseUrl())?.isNotEmpty ?? false;
    _hasOnDeviceModel  = (await Secrets.instance.getOnDeviceModelPath())?.isNotEmpty ?? false;
  }

  /// Wipe every stored secret. Used by "Forget all keys".
  Future<void> forgetAllSecrets() async {
    await Secrets.instance.clearAll();
    await _refreshKeyFlags();
    notifyListeners();
  }
}
