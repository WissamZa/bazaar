import 'package:shared_preferences/shared_preferences.dart';

import 'llm_extractor.dart';
import 'secrets.dart';

/// Which strategy the scraper should use for product-data extraction.
enum ExtractionStrategy {
  /// Tier 1 only — SearXNG → result pages → JSON-LD/OG parse.
  schemaOnly,

  /// Tier 1 + Tier 2 — schema first, cloud LLM fallback.
  schemaThenCloudLlm,

  /// Tier 1 + Tier 3 — schema first, on-device LLM fallback (fully offline).
  schemaThenOnDevice,

  /// Tier 1 + Tier 2 + Tier 3.
  schemaCloudOnDevice,

  /// Tier 2 only (debug/testing).
  cloudLlmOnly,

  /// Tier 3 only (debug/testing).
  onDeviceOnly,
}

extension ExtractionStrategyX on ExtractionStrategy {
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

/// Which online source a barcode lookup should target.
enum LookupSource { auto, openFoodFacts, searxng }

/// Which LLM providers have a usable secret configured.
class KeyPresence {
  final bool gemini;
  final bool openAi;
  final bool groq;
  final bool cerebras;
  final bool ollamaBaseUrl;
  final bool onDeviceModel;

  const KeyPresence({
    required this.gemini,
    required this.openAi,
    required this.groq,
    required this.cerebras,
    required this.ollamaBaseUrl,
    required this.onDeviceModel,
  });

  const KeyPresence.empty()
    : gemini = false,
      openAi = false,
      groq = false,
      cerebras = false,
      ollamaBaseUrl = false,
      onDeviceModel = false;

  bool forProvider(LlmProvider p) => switch (p) {
    LlmProvider.gemini => gemini,
    LlmProvider.openai => openAi,
    LlmProvider.groq => groq,
    LlmProvider.cerebras => cerebras,
    LlmProvider.ollama => ollamaBaseUrl,
  };
}

/// Persisted, NON-SECRET scraping/LLM configuration. API keys live only in
/// [Secrets] (Keystore/Keychain) — presence flags come from [KeyPresence].
class ScrapingConfig {
  final ExtractionStrategy strategy;
  final LlmProvider provider;
  final String model;
  final String baseUrl;

  /// SECURITY: default empty — the user must configure their own SearXNG
  /// instance. (v1.4.0's audit Finding 1 removed a hardcoded private host.)
  final String searxngUrl;
  final bool autoLoadOnDevice;

  const ScrapingConfig({
    this.strategy = ExtractionStrategy.schemaThenCloudLlm,
    this.provider = LlmProvider.gemini,
    this.model = '',
    this.baseUrl = '',
    this.searxngUrl = '',
    this.autoLoadOnDevice = false,
  });

  bool get isSearxngConfigured =>
      searxngUrl.isNotEmpty && Uri.tryParse(searxngUrl)?.hasScheme == true;

  /// True when the config can actually run the chosen strategy end-to-end.
  bool isConfigComplete(KeyPresence keys) {
    if (!isSearxngConfigured && strategy.usesSchema) return false;
    if (!strategy.usesCloudLlm && !strategy.usesOnDevice) return true;
    if (strategy.usesCloudLlm && keys.forProvider(provider)) return true;
    if (strategy.usesOnDevice && keys.onDeviceModel) return true;
    return false;
  }

  ScrapingConfig copyWith({
    ExtractionStrategy? strategy,
    LlmProvider? provider,
    String? model,
    String? baseUrl,
    String? searxngUrl,
    bool? autoLoadOnDevice,
  }) => ScrapingConfig(
    strategy: strategy ?? this.strategy,
    provider: provider ?? this.provider,
    model: model ?? this.model,
    baseUrl: baseUrl ?? this.baseUrl,
    searxngUrl: searxngUrl ?? this.searxngUrl,
    autoLoadOnDevice: autoLoadOnDevice ?? this.autoLoadOnDevice,
  );

  // ── Persistence (SharedPreferences — non-secret only) ─────────────────
  static const _kStrategy = 'scraping.strategy';
  static const _kLlmProvider = 'scraping.llm_provider';
  static const _kLlmModel = 'scraping.llm_model';
  static const _kLlmBaseUrl = 'scraping.llm_base_url';
  static const _kSearxngUrl = 'scraping.searxng_url';
  static const _kAutoLoadOnDev = 'scraping.autoload_on_device';

  static Future<ScrapingConfig> load() async {
    final sp = await SharedPreferences.getInstance();
    final url = sp.getString(_kSearxngUrl) ?? '';
    return ScrapingConfig(
      strategy: ExtractionStrategy.values.firstWhere(
        (e) => e.name == sp.getString(_kStrategy),
        orElse: () => ExtractionStrategy.schemaThenCloudLlm,
      ),
      provider: LlmProvider.values.firstWhere(
        (e) => e.name == sp.getString(_kLlmProvider),
        orElse: () => LlmProvider.gemini,
      ),
      model: sp.getString(_kLlmModel) ?? '',
      baseUrl: sp.getString(_kLlmBaseUrl) ?? '',
      searxngUrl: url,
      autoLoadOnDevice: sp.getBool(_kAutoLoadOnDev) ?? false,
    );
  }

  Future<void> save() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kStrategy, strategy.name);
    await sp.setString(_kLlmProvider, provider.name);
    if (model.isEmpty) {
      await sp.remove(_kLlmModel);
    } else {
      await sp.setString(_kLlmModel, model);
    }
    if (baseUrl.isEmpty) {
      await sp.remove(_kLlmBaseUrl);
    } else {
      await sp.setString(_kLlmBaseUrl, baseUrl);
    }
    await sp.setString(_kSearxngUrl, searxngUrl);
    await sp.setBool(_kAutoLoadOnDev, autoLoadOnDevice);
  }

  /// Validate before saving a SearXNG URL (audit Finding 11).
  static void validateSearxngUrl(String v) {
    final parsed = Uri.tryParse(v);
    if (v.isNotEmpty &&
        (parsed == null ||
            !parsed.hasScheme ||
            (parsed.scheme != 'http' && parsed.scheme != 'https'))) {
      throw ArgumentError(
        'SearXNG URL must be a valid http(s) URL (got: "$v")',
      );
    }
  }
}

/// Snapshot of the secret-presence flags, read from [Secrets].
Future<KeyPresence> readKeyPresence() async {
  final s = Secrets.instance;
  return KeyPresence(
    gemini: ((await s.getGeminiKey())?.isNotEmpty ?? false),
    openAi: ((await s.getOpenAiKey())?.isNotEmpty ?? false),
    groq: ((await s.getGroqKey())?.isNotEmpty ?? false),
    cerebras: ((await s.getCerebrasKey())?.isNotEmpty ?? false),
    ollamaBaseUrl: ((await s.getOllamaBaseUrl())?.isNotEmpty ?? false),
    onDeviceModel: ((await s.getOnDeviceModelPath())?.isNotEmpty ?? false),
  );
}
