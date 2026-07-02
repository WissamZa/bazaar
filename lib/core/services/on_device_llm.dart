import 'dart:convert';
import 'dart:io';

import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'llm_extractor.dart';
import 'product_schema_parser.dart';
import 'secrets.dart';

// Re-exports for the public API
export 'package:flutter_gemma/flutter_gemma.dart'
    show ModelType, PreferredBackend;

/// Tier 3 extractor: runs a small LLM **fully on-device** via MediaPipe.
///
/// Uses the `flutter_gemma` package (the most mature Flutter binding for
/// MediaPipe LLM Inference — supports Android, iOS, Desktop, and even Web).
/// Despite the name, it works with Gemma AND Llama 3.x AND Qwen 2.5, since
/// they all use the same MediaPipe `.task` runtime format.
///
/// API flow (flutter_gemma 1.1.x legacy singleton):
///   1. `FlutterGemmaPlugin.instance.modelManager.setModelPath(path)` —
///      register the .task file path (deprecated but still works).
///   2. `FlutterGemmaPlugin.instance.createModel(modelType: ModelType.gemmaIt, maxTokens: …, preferredBackend: gpu)`
///      → returns `InferenceModel`.
///   3. `model.createSession(temperature: 0, topK: 40, maxOutputTokens: 300, systemInstruction: …)`
///      → returns `InferenceModelSession`.
///   4. `session.addQueryChunk(Message.text(text: prompt, isUser: true))` —
///      add the user prompt.
///   5. `session.getResponse()` → returns the LLM response as a string
///      (no arguments — prompt is added via addQueryChunk).
///   6. `session.close()` / `model.close()` to free resources.
///
/// NATIVE SETUP REQUIRED (one-time per platform):
/// ──────────────────────────────────────────────
/// Android — `android/app/build.gradle`, inside `android { … }`:
///     packagingOptions {
///         jniLibs { useLegacyPackaging true }
///     }
/// iOS     — Podfile: ensure `platform :ios, '15.0'` or higher.
///
/// MODEL DOWNLOAD:
///   The user picks one of [OnDeviceModel.preset] options in Settings and
///   taps "Download model". We fetch the .task file from HuggingFace and
///   save it to the app's internal storage (NOT shared preferences, NOT
///   external storage — kept inside the app sandbox so other apps can't
///   read it).
///
/// SECURITY:
///   • The model file lives inside the app's private files dir on Android
///     (`/data/data/<pkg>/files/...`), which is sandboxed.
///   • No API key is required — inference is fully local.
///   • No network calls happen during inference; only during download.
class OnDeviceLlm {
  OnDeviceLlm._();
  static final OnDeviceLlm instance = OnDeviceLlm._();

  // FlutterGemmaPlugin.instance is the legacy singleton accessor that still
  // works in flutter_gemma 1.1.x. It exposes `modelManager`, `createModel`,
  // and `close`. The newer `FlutterGemma()` API requires an `initialize()`
  // call at app startup and a more complex installation flow.
  final _gemma = FlutterGemmaPlugin.instance;
  bool _loading = false;
  InferenceModel? _model;
  String? _loadedModelPath;

  /// True if a model has been loaded into memory.
  bool get isLoaded => _model != null;

  /// Path of the currently-loaded model (for display in settings).
  String? get loadedModelPath => _loadedModelPath;

  /// Pre-vetted model presets. All URLs are **verified to download
  /// without authentication** (HTTP 200 + real bytes returned).
  ///
  /// Verified 2026-07-02 by curl-testing each URL. The previous list pointed
  /// at gated models that returned HTTP 401 — this list only contains
  /// ungated, public .task files from the `litert-community` org on
  /// HuggingFace.
  ///
  /// Sizes are approximate (rounded to the nearest 100 MB from the actual
  /// Content-Length headers).
  static const preset = <OnDeviceModel>[
    OnDeviceModel(
      id: 'qwen2.5-0.5b-instruct-q8',
      name: 'Qwen 2.5 0.5B (Q8, ~520 MB) — fastest',
      sizeMb: 522,
      url: 'https://huggingface.co/litert-community/Qwen2.5-0.5B-Instruct/resolve/main/Qwen2.5-0.5B-Instruct_multi-prefill-seq_q8_ekv1280.task',
      modelType: ModelType.gemmaIt,
      recommended: true,
    ),
    OnDeviceModel(
      id: 'qwen2.5-1.5b-instruct-q8',
      name: 'Qwen 2.5 1.5B (Q8, ~1.5 GB) — best Arabic',
      sizeMb: 1523,
      url: 'https://huggingface.co/litert-community/Qwen2.5-1.5B-Instruct/resolve/main/Qwen2.5-1.5B-Instruct_multi-prefill-seq_q8_ekv1280.task',
      modelType: ModelType.gemmaIt,
    ),
    OnDeviceModel(
      id: 'tinyllama-1.1b-chat-q8',
      name: 'TinyLlama 1.1B Chat (Q8, ~1.1 GB)',
      sizeMb: 1095,
      url: 'https://huggingface.co/litert-community/TinyLlama-1.1B-Chat-v1.0/resolve/main/TinyLlama-1.1B-Chat-v1.0_multi-prefill-seq_q8_ekv1280.task',
      modelType: ModelType.gemmaIt,
    ),
    OnDeviceModel(
      id: 'phi-4-mini-instruct-q8',
      name: 'Phi-4 mini instruct (Q8, ~3.7 GB) — best quality',
      sizeMb: 3761,
      url: 'https://huggingface.co/litert-community/Phi-4-mini-instruct/resolve/main/Phi-4-mini-instruct_multi-prefill-seq_q8_ekv1280.task',
      modelType: ModelType.gemmaIt,
    ),
  ];

  /// Returns the absolute path where the model file SHOULD live.
  /// Does not imply the file exists.
  static Future<String> modelFilePath(String modelId) async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/on_device_llm/$modelId.task';
  }

  /// True if the model file is already present on disk.
  static Future<bool> isModelDownloaded(String modelId) async {
    final path = await modelFilePath(modelId);
    final f = File(path);
    return f.existsSync() && f.lengthSync() > 1024 * 1024; // >1 MB sanity
  }

  /// Downloads [modelId] to app-private storage.
  /// Reports progress via [onProgress] (0.0–1.0).
  ///
  /// Throws a [StateError] with a human-readable message on failure:
  ///   - HTTP 401 → "model is gated, requires a HuggingFace token"
  ///   - HTTP 404 → "URL is wrong, model file moved or renamed"
  ///   - HTTP 5xx → "HuggingFace is having issues, try again later"
  ///   - timeout / network → original error wrapped with context
  static Future<String> downloadModel(
    String modelId, {
    void Function(double progress)? onProgress,
  }) async {
    final m = preset.firstWhere((m) => m.id == modelId);
    final path = await modelFilePath(modelId);
    final file = File(path);
    await file.parent.create(recursive: true);

    // Clean up any partial file from a previous failed download.
    if (file.existsSync()) {
      try {
        await file.delete();
      } catch (_) {}
    }

    final req = http.Request('GET', Uri.parse(m.url));
    // HuggingFace's CDN sometimes 403s without a UA.
    req.headers['User-Agent'] =
        'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/124.0.0.0 Mobile Safari/537.36';
    req.headers['Accept'] = 'application/octet-stream,*/*;q=0.8';

    final client = http.Client();
    http.StreamedResponse stream;
    try {
      stream = await client.send(req).timeout(const Duration(seconds: 30));
    } catch (e) {
      client.close();
      throw StateError(
        'Download failed: cannot reach HuggingFace ($e). '
        'Check your internet connection and try again.',
      );
    }

    if (stream.statusCode != 200) {
      final reason = stream.reasonPhrase ?? 'unknown';
      client.close();
      String hint;
      switch (stream.statusCode) {
        case 401:
          hint = 'This model is gated and requires a HuggingFace access token. '
              'The preset list should only contain ungated models — please '
              'report this issue.';
          break;
        case 403:
          hint = 'HuggingFace refused the request (403). The model may have '
              'been made private, or your IP/region is blocked.';
          break;
        case 404:
          hint = 'The model file was not found (404). The repo may have been '
              'renamed or the file removed. Please report this issue.';
          break;
        case 429:
          hint = 'HuggingFace rate-limited the request (429). Wait a minute '
              'and try again.';
          break;
        case 500:
        case 502:
        case 503:
          hint = 'HuggingFace is having server issues (${stream.statusCode}). '
              'Try again in a few minutes.';
          break;
        default:
          hint = 'Unexpected HTTP ${stream.statusCode} $reason.';
      }
      throw StateError('Download failed: HTTP ${stream.statusCode}. $hint');
    }

    final total = stream.contentLength ?? (m.sizeMb * 1024 * 1024);
    final sink = file.openWrite();
    var received = 0;
    var lastProgress = -1.0;
    Object? error;
    try {
      await for (final chunk in stream.stream) {
        sink.add(chunk);
        received += chunk.length;
        final p = received / total;
        // Throttle progress callbacks to avoid flooding the UI — only call
        // when progress changes by ≥1%.
        if (onProgress != null && (p - lastProgress).abs() >= 0.01) {
          lastProgress = p;
          onProgress(p);
        }
      }
      await sink.flush();
    } catch (e) {
      error = e;
    } finally {
      try {
        await sink.close();
      } catch (_) {}
      client.close();
    }

    // If the stream threw, delete the partial file and rethrow.
    if (error != null) {
      try {
        if (file.existsSync()) await file.delete();
      } catch (_) {}
      throw StateError('Download interrupted: $error. Partial file deleted.');
    }

    // Sanity check: file should be at least 1 MB.
    final size = await file.length();
    if (size < 1024 * 1024) {
      try {
        await file.delete();
      } catch (_) {}
      throw StateError(
        'Downloaded file is only $size bytes — expected ~${m.sizeMb} MB. '
        'The file was deleted. Try again.',
      );
    }

    await Secrets.instance.setOnDeviceModelPath(path);
    await Secrets.instance.setOnDeviceModelName(m.name);
    return path;
  }

  /// Load (or reload) the model into memory. Safe to call repeatedly.
  ///
  /// NOTE: `flutter_gemma`'s `createModel` reads the model file from a path
  /// managed by `ModelFileManager`. The model file is registered there with
  /// `modelManager.setModelPath(path, fileType: ModelFileType.task)`, then
  /// `createModel` is called without a path argument. This indirection
  /// exists because `flutter_gemma` also supports in-app downloads of models
  /// from HuggingFace via a managed download UI.
  Future<void> load() async {
    if (_loading || _model != null) return;
    _loading = true;
    try {
      final modelPath = await Secrets.instance.getOnDeviceModelPath();
      if (modelPath == null || !File(modelPath).existsSync()) {
        throw StateError('No on-device model downloaded. Visit Settings → LLM.');
      }

      // Register the model file path with flutter_gemma's file manager.
      // NOTE: `setModelPath` is deprecated in flutter_gemma ≥1.1 in favour
      // of `setActiveModel(ModelSpec(...))`, but it still works and is
      // simpler. If/when it's removed, migrate to:
      //   _gemma.modelManager.setActiveModel(ModelSpec(
      //     modelType: ModelType.gemmaIt,
      //     path: modelPath,
      //     fileType: ModelFileType.task,
      //   ));
      // ignore: deprecated_member_use
      await _gemma.modelManager.setModelPath(modelPath);

      _model = await _gemma.createModel(
        modelType: ModelType.gemmaIt,
        maxTokens: 1024,
        preferredBackend: PreferredBackend.gpu,
      );
      _loadedModelPath = modelPath;
    } finally {
      _loading = false;
    }
  }

  /// Unload the model — frees ~1.5–3 GB of RAM. Safe to call when not loaded.
  Future<void> unload() async {
    try {
      await _model?.close();
    } catch (_) {}
    _model = null;
    _loadedModelPath = null;
  }

  /// Run extraction. Returns null on any failure (model not loaded, OOM, bad
  /// response, etc.) — the caller should fall back to a manual prompt.
  Future<ExtractedProduct?> extract({
    required String html,
    String? barcode,
  }) async {
    if (_model == null) await load();
    final model = _model;
    if (model == null) return null;

    final text = LlmExtractor.cleanHtmlForLlm(html, maxChars: 4000);
    if (text.length < 50) return null;

    final prompt = StringBuffer()
      ..writeln('Extract the product name, brand, price, currency, and image URL from the e-commerce page text below.')
      ..writeln('Reply with ONE JSON object only — no markdown, no prose.')
      ..writeln('Schema: {"name": string|null, "brand": string|null, "price": number|null, "currency": "SAR"|"AED"|"USD"|null, "image_url": string|null}');
    if (barcode != null && barcode.isNotEmpty) {
      prompt.writeln('Barcode: $barcode');
    }
    prompt
      ..writeln()
      ..writeln('PAGE TEXT:')
      ..writeln(text);

    InferenceModelSession? session;
    try {
      session = await model.createSession(
        temperature: 0.0,
        topK: 40,
        maxOutputTokens: 300,
        systemInstruction:
            'You extract structured product data. Respond ONLY as JSON.',
      );
      // flutter_gemma's API is two-step: addQueryChunk(Message) then getResponse().
      // (The older `getResponse(prompt)` signature was removed in 1.x.)
      await session.addQueryChunk(
        Message.text(text: prompt.toString(), isUser: true),
      );
      final out = await session.getResponse();
      return _parseJson(out);
    } catch (_) {
      return null;
    } finally {
      try {
        await session?.close();
      } catch (_) {}
    }
  }

  static ExtractedProduct? _parseJson(String raw) {
    if (raw.isEmpty) return null;
    var s = raw.trim();
    // Models occasionally wrap output in ```json fences despite instructions.
    final fenceStart = s.indexOf('```');
    if (fenceStart != -1) {
      s = s.substring(fenceStart + 3);
      if (s.toLowerCase().startsWith('json')) s = s.substring(4);
      final fenceEnd = s.lastIndexOf('```');
      if (fenceEnd != -1) s = s.substring(0, fenceEnd);
      s = s.trim();
    }
    final start = s.indexOf('{');
    final end = s.lastIndexOf('}');
    if (start == -1 || end == -1 || end < start) return null;
    final jsonStr = s.substring(start, end + 1);
    try {
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return ExtractedProduct(
        name: (json['name'] as String?)?.trim().isEmpty ?? true
            ? null
            : (json['name'] as String).trim(),
        brand: (json['brand'] as String?)?.trim().isEmpty ?? true
            ? null
            : (json['brand'] as String).trim(),
        price: (json['price'] as num?)?.toDouble(),
        currency: json['currency'] as String?,
        imageUrl: json['image_url'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Description of a downloadable on-device model.
class OnDeviceModel {
  final String id;
  final String name;
  final int sizeMb;
  final String url;
  final ModelType modelType;
  final bool recommended;
  const OnDeviceModel({
    required this.id,
    required this.name,
    required this.sizeMb,
    required this.url,
    required this.modelType,
    this.recommended = false,
  });
}
