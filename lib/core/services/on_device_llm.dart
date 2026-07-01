import 'dart:convert';
import 'dart:io';

import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'llm_extractor.dart';
import 'product_schema_parser.dart';
import 'secrets.dart';

/// Tier 3 extractor: runs a small LLM **fully on-device** via MediaPipe.
///
/// Uses the `flutter_gemma` package (the most mature Flutter binding for
/// MediaPipe LLM Inference — supports Android, iOS, Desktop, and even Web).
/// Despite the name, it works with Gemma AND Llama 3.x AND Qwen 2.5, since
/// they all use the same MediaPipe `.task` runtime format.
///
/// API flow:
///   1. `FlutterGemma.instance.createModel(modelType: ModelType.gemmaIt, maxTokens: …, preferredBackend: gpu)`
///      → returns `InferenceModel`
///   2. `model.createSession(temperature: 0, topK: 40, maxOutputTokens: 300, systemInstruction: …)`
///      → returns `InferenceModelSession`
///   3. `session.getResponse(prompt)` → returns the LLM response as a string
///   4. `session.close()` / `model.close()` to free resources
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

  final _gemma = FlutterGemma();
  bool _loading = false;
  InferenceModel? _model;
  String? _loadedModelPath;

  /// True if a model has been loaded into memory.
  bool get isLoaded => _model != null;

  /// Path of the currently-loaded model (for display in settings).
  String? get loadedModelPath => _loadedModelPath;

  /// Pre-vetted model presets. Sizes are approximate.
  /// URLs are from HuggingFace's `litert-community` org (Google's official
  /// MediaPipe LLM model host).
  static const preset = <OnDeviceModel>[
    OnDeviceModel(
      id: 'gemma-2b-it-gpu-int4',
      name: 'Gemma 2B (INT4, GPU)',
      sizeMb: 2500,
      url:
          'https://huggingface.co/litert-community/gemma-2b-it-gpu-int4/resolve/main/gemma-2b-it-gpu-int4.task',
      modelType: ModelType.gemmaIt,
      recommended: true,
    ),
    OnDeviceModel(
      id: 'gemma-1.1-2b-it-gpu-int4',
      name: 'Gemma 1.1 2B (INT4, GPU)',
      sizeMb: 1700,
      url:
          'https://huggingface.co/litert-community/gemma-1.1-2b-it-gpu-int4/resolve/main/gemma-1.1-2b-it-gpu-int4.task',
      modelType: ModelType.gemmaIt,
    ),
    OnDeviceModel(
      id: 'llama-3.2-1b-instruct-gpu-int4',
      name: 'Llama 3.2 1B (INT4, GPU) — fastest',
      sizeMb: 700,
      url:
          'https://huggingface.co/litert-community/Llama-3.2-1B-Instruct-GPU-Int4/resolve/main/Llama-3.2-1B-Instruct-GPU-Int4.task',
      modelType: ModelType.gemmaIt, // MediaPipe treats all .task files the same
    ),
    OnDeviceModel(
      id: 'llama-3.2-3b-instruct-gpu-int4',
      name: 'Llama 3.2 3B (INT4, GPU) — better quality',
      sizeMb: 1900,
      url:
          'https://huggingface.co/litert-community/Llama-3.2-3B-Instruct-GPU-Int4/resolve/main/Llama-3.2-3B-Instruct-GPU-Int4.task',
      modelType: ModelType.gemmaIt,
    ),
    OnDeviceModel(
      id: 'qwen2.5-1.5b-instruct-gpu-int4',
      name: 'Qwen 2.5 1.5B (best Arabic)',
      sizeMb: 900,
      url:
          'https://huggingface.co/litert-community/Qwen2.5-1.5B-Instruct-GPU-Int4/resolve/main/Qwen2.5-1.5B-Instruct-GPU-Int4.task',
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
  static Future<String> downloadModel(
    String modelId, {
    void Function(double progress)? onProgress,
  }) async {
    final m = preset.firstWhere((m) => m.id == modelId);
    final path = await modelFilePath(modelId);
    final file = File(path);
    await file.parent.create(recursive: true);

    final req = http.Request('GET', Uri.parse(m.url));
    final client = http.Client();
    final stream = await client.send(req);

    if (stream.statusCode != 200) {
      throw StateError('Download failed: HTTP ${stream.statusCode}');
    }
    final total = stream.contentLength ?? (m.sizeMb * 1024 * 1024);
    final sink = file.openWrite();
    var received = 0;
    await for (final chunk in stream.stream) {
      sink.add(chunk);
      received += chunk.length;
      onProgress?.call(received / total);
    }
    await sink.flush();
    await sink.close();
    client.close();

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
      await FlutterGemma.initialize();
      final modelPath = await Secrets.instance.getOnDeviceModelPath();
      if (modelPath == null || !File(modelPath).existsSync()) {
        throw StateError(
            'No on-device model downloaded. Visit Settings → LLM.');
      }

      // Use the plugin instance directly for the deprecated setModelPath
      await FlutterGemmaPlugin.instance.modelManager.setModelPath(modelPath);

      _model = await FlutterGemma.getActiveModel(
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
      ..writeln(
          'Extract the product name, brand, price, currency, and image URL from the e-commerce page text below.')
      ..writeln('Reply with ONE JSON object only — no markdown, no prose.')
      ..writeln(
          'Schema: {"name": string|null, "brand": string|null, "price": number|null, "currency": "SAR"|"AED"|"USD"|null, "image_url": string|null}');
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
      await session
          .addQueryChunk(Message.text(text: prompt.toString(), isUser: true));
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
