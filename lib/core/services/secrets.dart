import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Centralised, secure storage for all API keys and on-device model paths.
///
/// SECURITY NOTES
/// ──────────────
/// • On Android: keys are stored in the **Android Keystore** (AES-256, hardware
///   backed on devices with TEE/StrongBox). The `EncryptedSharedPreferences`
///   option enables extra encryption at rest.
/// • On iOS / macOS: keys go into the **Keychain** (Secure Enclave when
///   available).
/// • On Linux / Windows: `flutter_secure_storage` falls back to a libsecret /
///   DPAPI file — NOT as strong. For dev-only.
/// • Keys NEVER leave this layer. The LLM providers receive the key as a
///   runtime argument; we never log, print, or persist it anywhere else.
/// • We never store keys in `SharedPreferences` (plain XML on disk).
/// • We never embed keys in source code or compile-time `--dart-define`.
class Secrets {
  Secrets._();
  static final Secrets instance = Secrets._();

  // Secure storage config — works with both flutter_secure_storage 9.x and
  // 10.x. In v10, encryption is on by default and `encryptedSharedPreferences`
  // was removed (no longer needed — Keystore-backed encryption is automatic).
  // In v9, `encryptedSharedPreferences: true` adds an extra AES layer on top.
  //
  // We use conditional imports / try-catch in callers to stay compatible with
  // both. The constructor below uses only fields that exist in BOTH major
  // versions.
  final _storage = const FlutterSecureStorage(
    // Android: v9 supports `encryptedSharedPreferences`, v10 enables
    // encryption by default and removed the option. Passing only fields
    // common to both versions keeps us compatible with either.
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  // ── Keys ────────────────────────────────────────────────────────────────
  static const _kGeminiApiKey   = 'llm.gemini.api_key';
  static const _kOpenAiApiKey   = 'llm.openai.api_key';
  static const _kGroqApiKey     = 'llm.groq.api_key';
  static const _kCerebrasApiKey = 'llm.cerebras.api_key';
  static const _kOllamaBaseUrl  = 'llm.ollama.base_url';
  static const _kOnDeviceModelPath = 'llm.on_device.model_path';
  static const _kOnDeviceModelName = 'llm.on_device.model_name';

  // ── Getters / setters ──────────────────────────────────────────────────
  Future<String?> getGeminiKey()   => _storage.read(key: _kGeminiApiKey);
  Future<void> setGeminiKey(String? v) => _writeOrDelete(_kGeminiApiKey, v);

  Future<String?> getOpenAiKey()   => _storage.read(key: _kOpenAiApiKey);
  Future<void> setOpenAiKey(String? v) => _writeOrDelete(_kOpenAiApiKey, v);

  Future<String?> getGroqKey()     => _storage.read(key: _kGroqApiKey);
  Future<void> setGroqKey(String? v) => _writeOrDelete(_kGroqApiKey, v);

  Future<String?> getCerebrasKey() => _storage.read(key: _kCerebrasApiKey);
  Future<void> setCerebrasKey(String? v) => _writeOrDelete(_kCerebrasApiKey, v);

  Future<String?> getOllamaBaseUrl() => _storage.read(key: _kOllamaBaseUrl);
  Future<void> setOllamaBaseUrl(String? v) => _writeOrDelete(_kOllamaBaseUrl, v);

  Future<String?> getOnDeviceModelPath() =>
      _storage.read(key: _kOnDeviceModelPath);
  Future<void> setOnDeviceModelPath(String? v) =>
      _writeOrDelete(_kOnDeviceModelPath, v);

  Future<String?> getOnDeviceModelName() =>
      _storage.read(key: _kOnDeviceModelName);
  Future<void> setOnDeviceModelName(String? v) =>
      _writeOrDelete(_kOnDeviceModelName, v);

  // ── Helpers ────────────────────────────────────────────────────────────
  Future<void> _writeOrDelete(String key, String? value) async {
    if (value == null || value.isEmpty) {
      await _storage.delete(key: key);
    } else {
      await _storage.write(key: key, value: value);
    }
  }

  /// Wipe every secret. Used by the "Forget all keys" button in settings.
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
