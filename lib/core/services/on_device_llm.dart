import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'llm_common.dart';
import 'secrets.dart';

export 'llm_common.dart' show ExtractedProduct;
export 'package:flutter_gemma/flutter_gemma.dart'
    show ModelType, PreferredBackend;

/// Tier 3 extractor: runs a small LLM **fully on-device** via MediaPipe
/// (flutter_gemma 1.7.x modern API).
///
/// The app downloads the .task file itself (streaming + SHA-256 checks) into
/// the app sandbox, registers it once via `FlutterGemma.installModel()
/// .fromFile(path).install()`, and loads it with `getActiveModel`.
///
/// NATIVE SETUP REQUIRED (one-time per platform):
///   Android — `android/app/build.gradle`:
///       packagingOptions { jniLibs { useLegacyPackaging true } }
///   iOS — Podfile: `platform :ios, '15.0'` or higher.
class OnDeviceLlm {
  OnDeviceLlm._();
  static final OnDeviceLlm instance = OnDeviceLlm._();

  InferenceModel? _model;
  String? _loadedModelPath;
  bool _loading = false;

  bool get isLoaded => _model != null;
  String? get loadedModelPath => _loadedModelPath;

  /// Pre-vetted model presets. All URLs are **verified to download without
  /// authentication** (ungated, public .task files from the `litert-community`
  /// org on HuggingFace).
  ///
  /// Sizes are approximate (rounded from actual Content-Length headers).
  static const preset = <OnDeviceModel>[
    OnDeviceModel(
      id: 'qwen2.5-0.5b-instruct-q8',
      name: 'Qwen 2.5 0.5B (Q8, ~520 MB) — fastest',
      sizeMb: 522,
      url:
          'https://huggingface.co/litert-community/Qwen2.5-0.5B-Instruct/resolve/main/Qwen2.5-0.5B-Instruct_multi-prefill-seq_q8_ekv1280.task',
      recommended: true,
      // SECURITY: expected SHA-256 of the .task file, verified after
      // download to detect CDN compromise or MITM. Empty = skipped (set
      // after a trusted download to lock the supply chain).
      expectedSha256: '',
    ),
    OnDeviceModel(
      id: 'qwen2.5-1.5b-instruct-q8',
      name: 'Qwen 2.5 1.5B (Q8, ~1.5 GB) — best Arabic',
      sizeMb: 1523,
      url:
          'https://huggingface.co/litert-community/Qwen2.5-1.5B-Instruct/resolve/main/Qwen2.5-1.5B-Instruct_multi-prefill-seq_q8_ekv1280.task',
      expectedSha256: '',
    ),
    OnDeviceModel(
      id: 'tinyllama-1.1b-chat-q8',
      name: 'TinyLlama 1.1B Chat (Q8, ~1.1 GB)',
      sizeMb: 1095,
      url:
          'https://huggingface.co/litert-community/TinyLlama-1.1B-Chat-v1.0/resolve/main/TinyLlama-1.1B-Chat-v1.0_multi-prefill-seq_q8_ekv1280.task',
      expectedSha256: '',
    ),
    OnDeviceModel(
      id: 'phi-4-mini-instruct-q8',
      name: 'Phi-4 mini instruct (Q8, ~3.7 GB) — best quality',
      sizeMb: 3761,
      url:
          'https://huggingface.co/litert-community/Phi-4-mini-instruct/resolve/main/Phi-4-mini-instruct_multi-prefill-seq_q8_ekv1280.task',
      expectedSha256: '',
    ),
  ];

  /// Absolute path where the model file SHOULD live (not implying existence).
  static Future<String> modelFilePath(String modelId) async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/on_device_llm/$modelId.task';
  }

  static Future<bool> isModelDownloaded(String modelId) async {
    final f = File(await modelFilePath(modelId));
    return f.existsSync() && f.lengthSync() > 1024 * 1024;
  }

  /// Downloads [modelId] to app-private storage with throttled [onProgress]
  /// callbacks (0.0–1.0). Throws [StateError] with a human-readable message
  /// on failure. Partial files are always cleaned up.
  static Future<String> downloadModel(
    String modelId, {
    void Function(double progress)? onProgress,
  }) async {
    final m = preset.firstWhere((m) => m.id == modelId);
    final path = await modelFilePath(modelId);
    final file = File(path);
    await file.parent.create(recursive: true);
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
    final http.StreamedResponse stream;
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
      client.close();
      throw StateError(
        'Download failed: HTTP ${stream.statusCode}. ${_statusHint(stream.statusCode)}',
      );
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
        // Throttle progress callbacks to ≥1% steps.
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

    if (error != null) {
      try {
        if (file.existsSync()) await file.delete();
      } catch (_) {}
      throw StateError('Download interrupted: $error. Partial file deleted.');
    }

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

    // SECURITY: verify the downloaded file against the expected SHA-256.
    // On mismatch the file is deleted and the runtime refuses to register it.
    if (m.expectedSha256.isNotEmpty) {
      final actual = await computeSha256(file);
      if (actual.toLowerCase() != m.expectedSha256.toLowerCase()) {
        try {
          await file.delete();
        } catch (_) {}
        throw StateError(
          'SHA-256 mismatch!\n  Expected: ${m.expectedSha256}\n'
          '  Actual:   $actual\nThe file was deleted. This may indicate a '
          'corrupt download or a compromised supply chain.',
        );
      }
    }

    await Secrets.instance.setOnDeviceModelPath(path);
    await Secrets.instance.setOnDeviceModelName(m.name);
    return path;
  }

  static String _statusHint(int code) => switch (code) {
    401 =>
      'This model is gated and requires a HuggingFace access token. Please report this issue.',
    403 =>
      'HuggingFace refused the request. The model may have been made private, or your IP/region is blocked.',
    404 =>
      'The model file was not found (repo renamed or file removed). Please report this issue.',
    429 => 'HuggingFace rate-limited the request. Wait a minute and try again.',
    500 ||
    502 ||
    503 => 'HuggingFace is having server issues. Try again in a few minutes.',
    _ => 'Unexpected HTTP $code.',
  };

  /// Register the downloaded file with flutter_gemma and load it into
  /// memory. Safe to call repeatedly; no-op when already loaded/loading.
  Future<void> load() async {
    if (_loading || _model != null) return;
    _loading = true;
    try {
      final modelPath = await Secrets.instance.getOnDeviceModelPath();
      if (modelPath == null || !File(modelPath).existsSync()) {
        throw StateError(
          'No on-device model downloaded. Visit Settings → Search & AI.',
        );
      }
      if (_loadedModelPath != modelPath && _model != null) {
        await unload();
      }
      _model = await FlutterGemma.getActiveModel(
        maxTokens: 1024,
        preferredBackend: PreferredBackend.gpu,
      );
      _loadedModelPath = modelPath;
    } finally {
      _loading = false;
    }
  }

  /// Ensure a model file is registered as the active model. Called after
  /// download (and at app start when autoload is enabled). Registers only
  /// when no active model is set yet — re-registering on every start would
  /// trigger file scans for a multi-GB file.
  static Future<void> registerDownloadedModel() async {
    final path = await Secrets.instance.getOnDeviceModelPath();
    if (path == null || !File(path).existsSync()) {
      throw StateError('No on-device model downloaded.');
    }
    await FlutterGemma.installModel(
      modelType: ModelType.gemmaIt,
    ).fromFile(path).install();
  }

  /// Unload the model — frees RAM. Safe to call when not loaded.
  Future<void> unload() async {
    try {
      await _model?.close();
    } catch (_) {}
    _model = null;
    _loadedModelPath = null;
  }

  /// Run extraction. Returns null on any failure — callers fall back.
  Future<ExtractedProduct?> extract({
    required String html,
    String? barcode,
  }) async {
    if (_model == null) await load();
    final model = _model;
    if (model == null) return null;

    final text = LlmText.cleanHtmlForLlm(html, maxChars: 4000);
    if (text.length < 50) return null;

    final prompt = StringBuffer()
      ..writeln(
        'Extract the product name, brand, price, currency, and image URL from the e-commerce page text below.',
      )
      ..writeln('Reply with ONE JSON object only — no markdown, no prose.')
      ..writeln(
        'Schema: {"name": string|null, "brand": string|null, "price": number|null, "currency": "SAR"|"AED"|"USD"|null, "image_url": string|null}',
      );
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
      await session.addQueryChunk(
        Message.text(text: prompt.toString(), isUser: true),
      );
      final out = await session.getResponse();
      return LlmJson.parseExtracted(out);
    } catch (_) {
      return null;
    } finally {
      try {
        await session?.close();
      } catch (_) {}
    }
  }

  /// Streaming SHA-256 of [file] in 1 MB chunks (never loads a multi-GB
  /// model into memory at once).
  static Future<String> computeSha256(File file) async {
    final raf = await file.open();
    try {
      final digest = await crypto.sha256
          .bind(_fileByteStream(raf, 1024 * 1024))
          .last;
      return digest.toString();
    } finally {
      await raf.close();
    }
  }

  static Stream<List<int>> _fileByteStream(
    RandomAccessFile raf,
    int chunkSize,
  ) async* {
    final buffer = Uint8List(chunkSize);
    while (true) {
      final n = await raf.readInto(buffer);
      if (n == 0) break;
      yield buffer.sublist(0, n);
    }
  }
}

/// Description of a downloadable on-device model.
class OnDeviceModel {
  final String id;
  final String name;
  final int sizeMb;
  final String url;
  final bool recommended;

  /// Expected SHA-256 (lowercase hex). Empty = verification skipped.
  final String expectedSha256;

  const OnDeviceModel({
    required this.id,
    required this.name,
    required this.sizeMb,
    required this.url,
    this.recommended = false,
    this.expectedSha256 = '',
  });
}
