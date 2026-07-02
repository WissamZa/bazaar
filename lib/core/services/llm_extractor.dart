import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import 'product_schema_parser.dart';
import 'secrets.dart';

/// Which cloud LLM provider to use for Tier 2 extraction.
enum LlmProvider {
  gemini,    // Google Gemini — recommended, free tier 15 RPM
  openai,    // OpenAI-compatible (OpenAI, Azure, Together, OpenRouter…)
  groq,      // Groq — fastest latency, free tier 30 RPM
  cerebras,  // Cerebras — fastest inference, free beta
  ollama,    // local Ollama server on user's machine / Tailscale
}

extension LlmProviderX on LlmProvider {
  String get label => switch (this) {
        LlmProvider.gemini   => 'Google Gemini',
        LlmProvider.openai   => 'OpenAI-compatible',
        LlmProvider.groq     => 'Groq',
        LlmProvider.cerebras => 'Cerebras',
        LlmProvider.ollama   => 'Ollama (self-hosted)',
      };

  String get labelAr => switch (this) {
        LlmProvider.gemini   => 'جوجل جيميناي',
        LlmProvider.openai   => 'متوافق مع OpenAI',
        LlmProvider.groq     => 'جروك',
        LlmProvider.cerebras => 'سيريبراس',
        LlmProvider.ollama   => 'أولاما (محلي)',
      };

  String displayName(String locale) =>
      locale == 'ar' ? labelAr : label;

  /// Whether this provider needs an API key from [Secrets].
  bool get needsApiKey => this != LlmProvider.ollama;

  /// Default model id used if the user hasn't customised it.
  String get defaultModel => switch (this) {
        LlmProvider.gemini   => 'gemini-2.0-flash',
        LlmProvider.openai   => 'gpt-4o-mini',
        LlmProvider.groq     => 'llama-3.1-8b-instant',
        LlmProvider.cerebras => 'llama3.1-8b',
        LlmProvider.ollama   => 'llama3.2:3b',
      };

  /// Default base URL for OpenAI-compatible providers.
  String get defaultBaseUrl => switch (this) {
        LlmProvider.openai   => 'https://api.openai.com/v1',
        LlmProvider.groq     => 'https://api.groq.com/openai/v1',
        LlmProvider.cerebras => 'https://api.cerebras.ai/v1',
        LlmProvider.ollama   => 'http://localhost:11434/v1',
        LlmProvider.gemini   => '', // not used — has its own SDK
      };
}

/// Tier 2 extractor: feeds cleaned page text to a cloud LLM and parses its
/// JSON response.
///
/// SECURITY: API keys are read from [Secrets] at call time and never logged.
/// Only the cleaned page text is sent to the provider — never the user's
/// other data, never the API key in any prompt.
class LlmExtractor {
  LlmExtractor._();

  static const _systemPrompt = 'You extract structured product data from raw '
      'e-commerce HTML text. Respond ONLY as JSON with this exact schema: '
      '{"name": string|null, "brand": string|null, "price": number|null, '
      '"currency": "SAR"|"AED"|"USD"|null, "image_url": string|null}. '
      'If a field is missing or uncertain, use null. Do not invent values. '
      'Do not include markdown fences or any text outside the JSON object.';

  /// Pull plain text out of HTML, stripping scripts / styles / nav / footer
  /// so the LLM sees mostly product copy. Truncates to ~6 KB to stay inside
  /// the free tier token limits.
  static String cleanHtmlForLlm(String html, {int maxChars = 6000}) {
    final doc = html_parser.parse(html);
    doc.querySelectorAll(
      'script,style,noscript,nav,footer,header,svg,iframe,form,button',
    ).forEach((e) => e.remove());
    final text = doc.body?.text ?? '';
    final squashed = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (squashed.length <= maxChars) return squashed;
    return squashed.substring(0, maxChars);
  }

  /// Run extraction with the given provider. [html] is the raw page HTML.
  /// [barcode] is an optional hint passed to the model.
  static Future<ExtractedProduct?> extract({
    required LlmProvider provider,
    required String html,
    String? barcode,
    String? modelOverride,
    String? baseUrlOverride, // for OpenAI-compatible providers
  }) async {
    final text = cleanHtmlForLlm(html);
    if (text.length < 50) return null;

    final userPrompt = StringBuffer()
      ..writeln('Extract the product information from this e-commerce page text.');
    if (barcode != null && barcode.isNotEmpty) {
      userPrompt.writeln('Barcode (EAN-13): $barcode');
    }
    userPrompt
      ..writeln()
      ..writeln('HTML TEXT:')
      ..writeln(text);

    try {
      final String jsonStr;
      switch (provider) {
        case LlmProvider.gemini:
          jsonStr = await _runGemini(
            userPrompt.toString(),
            model: modelOverride ?? provider.defaultModel,
          );
          break;
        case LlmProvider.openai:
        case LlmProvider.groq:
        case LlmProvider.cerebras:
        case LlmProvider.ollama:
          jsonStr = await _runOpenAiCompatible(
            provider: provider,
            prompt: userPrompt.toString(),
            model: modelOverride ?? provider.defaultModel,
            baseUrl: baseUrlOverride ?? provider.defaultBaseUrl,
          );
          break;
      }

      return _parseJsonResponse(jsonStr);
    } catch (_) {
      return null;
    }
  }

  // ── Gemini via official SDK ─────────────────────────────────────────────
  static Future<String> _runGemini(String prompt, {required String model}) async {
    final apiKey = await Secrets.instance.getGeminiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw StateError('Gemini API key not set');
    }
    final m = GenerativeModel(
      model: model,
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        temperature: 0,
        maxOutputTokens: 300,
      ),
      systemInstruction: Content.text(_systemPrompt),
    );
    final resp = await m.generateContent([Content.text(prompt)]);
    return resp.text ?? '';
  }

  // ── OpenAI-compatible (OpenAI / Groq / Cerebras / Ollama) ───────────────
  static Future<String> _runOpenAiCompatible({
    required LlmProvider provider,
    required String prompt,
    required String model,
    required String baseUrl,
  }) async {
    final String? apiKey;
    switch (provider) {
      case LlmProvider.openai:
        apiKey = await Secrets.instance.getOpenAiKey();
        break;
      case LlmProvider.groq:
        apiKey = await Secrets.instance.getGroqKey();
        break;
      case LlmProvider.cerebras:
        apiKey = await Secrets.instance.getCerebrasKey();
        break;
      case LlmProvider.ollama:
        // Ollama doesn't need a key, but respects a custom base URL.
        apiKey = 'ollama'; // sentinel — Ollama ignores the Authorization header
        final custom = await Secrets.instance.getOllamaBaseUrl();
        if (custom != null && custom.isNotEmpty) baseUrl = custom;
        break;
      default:
        apiKey = null;
    }
    if (apiKey == null || apiKey.isEmpty) {
      throw StateError('${provider.label} API key not set');
    }

    final res = await http.post(
      Uri.parse('$baseUrl/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': model,
        'temperature': 0,
        'max_tokens': 300,
        'response_format': {'type': 'json_object'},
        'messages': [
          {'role': 'system', 'content': _systemPrompt},
          {'role': 'user', 'content': prompt},
        ],
      }),
    ).timeout(const Duration(seconds: 30));

    if (res.statusCode != 200) {
      throw StateError('${provider.label} HTTP ${res.statusCode}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final choices = data['choices'] as List?;
    if (choices == null || choices.isEmpty) return '';
    return (choices.first as Map<String, dynamic>)['message']['content']
            as String? ??
        '';
  }

  // ── Parse the LLM's JSON response ───────────────────────────────────────
  static ExtractedProduct? _parseJsonResponse(String raw) {
    if (raw.isEmpty) return null;
    // Strip any stray markdown fences if the model didn't respect response_format
    var s = raw.trim();
    if (s.startsWith('```')) {
      s = s.replaceAll(RegExp(r'^```(?:json)?\s*', caseSensitive: false), '')
           .replaceAll(RegExp(r'\s*```$'), '')
           .trim();
    }
    try {
      final json = jsonDecode(s) as Map<String, dynamic>;
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
