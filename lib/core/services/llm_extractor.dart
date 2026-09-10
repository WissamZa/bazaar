import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/io_client.dart';

import 'llm_common.dart';
import 'secrets.dart';

export 'llm_common.dart' show ExtractedProduct;

/// Which cloud LLM provider to use for Tier 2 extraction.
enum LlmProvider { gemini, openai, groq, cerebras, ollama }

extension LlmProviderX on LlmProvider {
  bool get needsApiKey => this != LlmProvider.ollama;

  String get defaultModel => switch (this) {
    LlmProvider.gemini => 'gemini-2.0-flash',
    LlmProvider.openai => 'gpt-4o-mini',
    LlmProvider.groq => 'llama-3.1-8b-instant',
    LlmProvider.cerebras => 'llama3.1-8b',
    LlmProvider.ollama => 'llama3.2:3b',
  };

  /// Default base URL for OpenAI-compatible providers (Gemini uses its SDK).
  String get defaultBaseUrl => switch (this) {
    LlmProvider.openai => 'https://api.openai.com/v1',
    LlmProvider.groq => 'https://api.groq.com/openai/v1',
    LlmProvider.cerebras => 'https://api.cerebras.ai/v1',
    LlmProvider.ollama => 'http://localhost:11434/v1',
    LlmProvider.gemini => '',
  };
}

/// Tier 2 extractor: feeds cleaned page text to a cloud LLM and parses its
/// JSON response.
///
/// SECURITY: API keys are read from [Secrets] at call time and never logged.
/// Only the cleaned page text is sent to the provider — never the user's
/// other data, never the key in any prompt.
///
/// TLS: standard certificate validation (enforced by dart:io). The v1 code
/// carried a "pinning" wrapper whose pin extraction always returned null —
/// i.e. pinning never actually happened. It was removed; dart:io already
/// validates certificates, and pinning arbitrary user-configured endpoints
/// is not meaningful without out-of-band pins. Cleartext HTTP is only ever
/// used for self-hosted Ollama (allowed explicitly by the Android network
/// security config for localhost).
class LlmExtractor {
  LlmExtractor._();

  /// Run extraction with the given provider. [html] is the raw page HTML.
  static Future<ExtractedProduct?> extract({
    required LlmProvider provider,
    required String html,
    String? barcode,
    String? modelOverride,
    String? baseUrlOverride,
  }) async {
    final text = LlmText.cleanHtmlForLlm(html);
    if (text.length < 50) return null;

    final userPrompt = StringBuffer()
      ..writeln(
        'Extract the product information from this e-commerce page text.',
      );
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
      }
      return LlmJson.parseExtracted(jsonStr);
    } catch (_) {
      return null;
    }
  }

  // ── Gemini via official SDK ────────────────────────────────────────────
  // The SDK exposes no timeout parameter, so wrap with .timeout() so a hung
  // request cannot stall the whole scraper chain.
  static Future<String> _runGemini(
    String prompt, {
    required String model,
  }) async {
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
      systemInstruction: Content.text(LlmPrompts.system),
    );
    try {
      final resp = await m
          .generateContent([Content.text(prompt)])
          .timeout(const Duration(seconds: 25));
      return resp.text ?? '';
    } on TimeoutException {
      throw StateError('Gemini SDK call exceeded 25 seconds');
    }
  }

  // ── OpenAI-compatible (OpenAI / Groq / Cerebras / Ollama) ──────────────
  static Future<String> _runOpenAiCompatible({
    required LlmProvider provider,
    required String prompt,
    required String model,
    required String baseUrl,
  }) async {
    String? apiKey;
    switch (provider) {
      case LlmProvider.openai:
        apiKey = await Secrets.instance.getOpenAiKey();
      case LlmProvider.groq:
        apiKey = await Secrets.instance.getGroqKey();
      case LlmProvider.cerebras:
        apiKey = await Secrets.instance.getCerebrasKey();
      case LlmProvider.ollama:
        // Ollama needs no key; a custom base URL always wins.
        apiKey = 'ollama';
        final custom = await Secrets.instance.getOllamaBaseUrl();
        if (custom != null && custom.isNotEmpty) baseUrl = custom;
      case LlmProvider.gemini:
        apiKey = null;
    }
    if (apiKey == null || apiKey.isEmpty) {
      throw StateError('${provider.name} API key not set');
    }

    final client = IOClient(
      HttpClient()..connectionTimeout = const Duration(seconds: 30),
    );
    try {
      final res = await client
          .post(
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
                {'role': 'system', 'content': LlmPrompts.system},
                {'role': 'user', 'content': prompt},
              ],
            }),
          )
          .timeout(const Duration(seconds: 35));

      if (res.statusCode != 200) {
        throw StateError('${provider.name} HTTP ${res.statusCode}');
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final choices = data['choices'] as List?;
      if (choices == null || choices.isEmpty) return '';
      return ((choices.first as Map<String, dynamic>)['message']
                  as Map<String, dynamic>)['content']
              as String? ??
          '';
    } finally {
      client.close();
    }
  }
}
