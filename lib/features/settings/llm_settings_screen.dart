import 'dart:io' show File;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/providers/locale_provider.dart';
import '../../core/providers/scraping_provider.dart';
import '../../core/services/llm_extractor.dart';
import '../../core/services/on_device_llm.dart';
import '../../core/services/secrets.dart';
import 'pipeline_debugger_screen.dart';

/// Full settings UI for Tier 1/2/3 scraping configuration.
/// Lets the user:
///   • pick extraction strategy
///   • pick cloud LLM provider
///   • enter / clear API keys (stored in secure storage)
///   • override model & base URL
///   • download / delete on-device LLM model
///   • configure SearXNG base URL
///   • forget all keys at once
class LlmSettingsScreen extends StatefulWidget {
  const LlmSettingsScreen({super.key});

  @override
  State<LlmSettingsScreen> createState() => _LlmSettingsScreenState();
}

class _LlmSettingsScreenState extends State<LlmSettingsScreen> {
  bool _downloading = false;
  double _downloadProgress = 0;
  String? _downloadStatus;

  /// Cached read of the stored on-device model name (for display).
  /// Reads from secure storage on first build only.
  Future<String?>? _storedModelNameFuture;
  Future<String?> _readStoredModelName() {
    _storedModelNameFuture ??= Secrets.instance.getOnDeviceModelName();
    return _storedModelNameFuture!;
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final isRtl = locale.isRtl;
    final s = context.watch<ScrapingProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(isRtl ? 'إعدادات البحث و LLM' : 'Search & LLM Settings'),
      ),
      body: ListView(
        children: [
          // ── Pipeline debugger ─────────────────────────────────────────
          // Prominent button at the top so the user can verify their config
          // actually works before relying on it.
          Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primaryContainer,
                  Theme.of(context).colorScheme.surfaceContainerHighest,
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: Icon(Icons.bug_report,
                  color: Theme.of(context).colorScheme.primary),
              title: Text(
                isRtl
                    ? 'تنقيح خط الأنابيب — اختبر أي باركود'
                    : 'Pipeline Debugger — test any barcode',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                isRtl
                    ? 'شاهد ماذا ترجع كل خطوة (OFF, SearXNG, JSON-LD, LLM)'
                    : 'See exactly what each step returns (OFF, SearXNG, JSON-LD, LLM)',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PipelineDebuggerScreen(),
                  ),
                );
              },
            ),
          ),

          // ── Strategy ────────────────────────────────────────────────
          _Section(isRtl ? 'استراتيجية الاستخراج' : 'Extraction strategy'),
          for (final strat in ExtractionStrategy.values)
            RadioListTile<ExtractionStrategy>(
              value: strat,
              groupValue: s.strategy,
              title: Text(strat.displayName(isRtl ? 'ar' : 'en')),
              onChanged: (v) => v == null ? null : s.setStrategy(v),
            ),

          // ── Config completeness banner ──────────────────────────────
          if (!s.isConfigComplete) ...[
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Theme.of(context).colorScheme.onErrorContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isRtl
                          ? 'الإعداد غير مكتمل — أكمل البيانات بالأسفل أو اختر استراتيجية مختلفة.'
                          : 'Config incomplete — fill in the fields below or pick a different strategy.',
                    ),
                  ),
                ],
              ),
            ),
          ],

          const Divider(),

          // ── Cloud LLM provider ──────────────────────────────────────
          if (s.strategy.usesCloudLlm) ...[
            _Section(isRtl ? 'مزود السحابة' : 'Cloud provider'),
            for (final p in LlmProvider.values)
              RadioListTile<LlmProvider>(
                value: p,
                groupValue: s.provider,
                title: Text(p.displayName(isRtl ? 'ar' : 'en')),
                subtitle: Text(
                  '${p.defaultModel} · ${p.needsApiKey ? "needs API key" : "self-hosted"}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                onChanged: (v) => v == null ? null : s.setProvider(v),
              ),

            // ── Model override ─────────────────────────────────────
            ListTile(
              leading: const Icon(Icons.memory),
              title: Text(isRtl ? 'اسم النموذج' : 'Model name'),
              subtitle: Text(
                s.model.isEmpty ? s.provider.defaultModel : s.model,
                style: TextStyle(
                  color: s.model.isEmpty ? Colors.grey : null,
                ),
              ),
              trailing: const Icon(Icons.edit, size: 18),
              onTap: () => _editString(
                title: isRtl ? 'اسم النموذج' : 'Model name',
                initial: s.model,
                hint: s.provider.defaultModel,
                onSubmit: s.setModel,
              ),
            ),

            // ── Base URL override (OpenAI-compatible providers only) ─
            if (s.provider != LlmProvider.gemini)
              ListTile(
                leading: const Icon(Icons.dns_outlined),
                title: Text(isRtl ? 'عنوان الخادم' : 'Base URL'),
                subtitle: Text(
                  s.baseUrl.isEmpty ? s.provider.defaultBaseUrl : s.baseUrl,
                  style: TextStyle(
                    color: s.baseUrl.isEmpty ? Colors.grey : null,
                  ),
                ),
                trailing: const Icon(Icons.edit, size: 18),
                onTap: () => _editString(
                  title: isRtl ? 'عنوان الخادم' : 'Base URL',
                  initial: s.baseUrl,
                  hint: s.provider.defaultBaseUrl,
                  onSubmit: s.setBaseUrl,
                ),
              ),

            // ── API key ────────────────────────────────────────────
            _buildApiKeyTile(s, isRtl),

            const Divider(),
          ],

          // ── On-device LLM ───────────────────────────────────────────
          if (s.strategy.usesOnDevice) ...[
            _Section(isRtl ? 'النموذج المحلي' : 'On-device LLM'),
            FutureBuilder<String?>(
              future: OnDeviceLlm.instance.loadedModelPath == null
                  ? _readStoredModelName()
                  : Future.value(OnDeviceLlm.instance.loadedModelPath),
              builder: (ctx, snap) {
                if (!s.hasOnDeviceModel) {
                  return _buildModelDownloader(isRtl);
                }
                final displayName = snap.data ??
                    (isRtl ? 'النموذج المحلي' : 'On-device model');
                return ListTile(
                  leading: const Icon(Icons.check_circle, color: Colors.green),
                  title: Text(isRtl ? 'النموذج جاهز' : 'Model ready'),
                  subtitle: Text(
                    (isRtl ? 'النموذج: ' : 'Model: ') + displayName,
                  ),
                  trailing: TextButton(
                    onPressed: () => _confirmDeleteModel(isRtl),
                    child: Text(
                      isRtl ? 'حذف' : 'Delete',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                );
              },
            ),

            SwitchListTile(
              secondary: const Icon(Icons.flash_on),
              title: Text(isRtl
                  ? 'تحميل النموذج تلقائياً عند بدء التطبيق'
                  : 'Auto-load model on app start'),
              subtitle: Text(isRtl
                  ? 'يستهلك RAM أكثر لكنه يسرع أول بحث'
                  : 'Uses more RAM but speeds up first search'),
              value: s.autoLoadOnDevice,
              onChanged: s.setAutoLoadOnDevice,
            ),

            const Divider(),
          ],

          // ── SearXNG base URL ────────────────────────────────────────
          _Section(isRtl ? 'خادم SearXNG' : 'SearXNG server'),
          ListTile(
            leading: const Icon(Icons.travel_explore_outlined),
            title: Text(isRtl ? 'عنوان SearXNG' : 'SearXNG URL'),
            subtitle: Text(
              s.searxngUrl,
              style: TextStyle(
                color: s.searxngUrl.isEmpty ? Colors.grey : null,
              ),
            ),
            trailing: const Icon(Icons.edit, size: 18),
            onTap: () => _editString(
              title: isRtl ? 'عنوان SearXNG' : 'SearXNG URL',
              initial: s.searxngUrl,
              hint: 'https://your-searxng.example:8080',
              onSubmit: s.setSearxngUrl,
            ),
          ),

          const Divider(),

          // ── Forget all keys ─────────────────────────────────────────
          ListTile(
            leading: Icon(Icons.delete_forever,
                color: Theme.of(context).colorScheme.error),
            title: Text(
              isRtl ? 'مسح كل المفاتيح' : 'Forget all API keys',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            subtitle: Text(isRtl
                ? 'يحذف كل المفاتيح من المخزن الآمن'
                : 'Wipes every key from secure storage'),
            onTap: () => _confirmForgetAll(isRtl),
          ),
        ],
      ),
    );
  }

  // ── API-key tile ─────────────────────────────────────────────────────
  Widget _buildApiKeyTile(ScrapingProvider s, bool isRtl) {
    final bool hasKey;
    final String keyLabel;
    final Future<void> Function(String?) setter;
    switch (s.provider) {
      case LlmProvider.gemini:
        hasKey = s.hasGeminiKey;
        keyLabel = 'Gemini API key';
        setter = s.setGeminiKey;
        break;
      case LlmProvider.openai:
        hasKey = s.hasOpenAiKey;
        keyLabel = 'OpenAI API key';
        setter = s.setOpenAiKey;
        break;
      case LlmProvider.groq:
        hasKey = s.hasGroqKey;
        keyLabel = 'Groq API key';
        setter = s.setGroqKey;
        break;
      case LlmProvider.cerebras:
        hasKey = s.hasCerebrasKey;
        keyLabel = 'Cerebras API key';
        setter = s.setCerebrasKey;
        break;
      case LlmProvider.ollama:
        hasKey = s.hasOllamaBaseUrl;
        keyLabel = 'Ollama base URL';
        setter = s.setOllamaBaseUrl;
        break;
    }

    return ListTile(
      leading: Icon(
        hasKey ? Icons.lock_clock : Icons.key_off,
        color: hasKey ? Colors.green : null,
      ),
      title: Text(keyLabel),
      subtitle: Text(hasKey
          ? (isRtl ? 'مخزّن بأمان' : 'Stored securely')
          : (isRtl ? 'لم يُضبط' : 'Not set')),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasKey)
            IconButton(
              icon: const Icon(Icons.visibility_off, size: 18),
              tooltip: isRtl ? 'مسح المفتاح' : 'Clear key',
              onPressed: () => setter(null),
            ),
          const Icon(Icons.edit, size: 18),
        ],
      ),
      onTap: () => _editSecret(
        title: keyLabel,
        isUrl: s.provider == LlmProvider.ollama,
        isRtl: isRtl,
        onSubmit: setter,
      ),
    );
  }

  // ── Model downloader ────────────────────────────────────────────────
  Widget _buildModelDownloader(bool isRtl) {
    if (_downloading) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: LinearProgressIndicator(value: _downloadProgress),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '${(isRtl ? "جاري التنزيل" : "Downloading")}: '
              '${(_downloadProgress * 100).toStringAsFixed(0)}%'
              '${_downloadStatus == null ? "" : " — $_downloadStatus"}',
            ),
          ),
        ],
      );
    }
    return Column(
      children: [
        for (final m in OnDeviceLlm.preset)
          ListTile(
            leading: Icon(m.recommended
                ? Icons.recommend
                : Icons.download_for_offline_outlined),
            title: Text(m.name),
            subtitle: Text(
              '${(m.sizeMb / 1024).toStringAsFixed(1)} GB · ${m.id}',
            ),
            trailing: m.recommended
                ? Chip(label: Text(isRtl ? 'موصى به' : 'Recommended'))
                : null,
            onTap: () => _downloadModel(m.id, isRtl),
          ),
      ],
    );
  }

  // ── Dialogs ─────────────────────────────────────────────────────────
  Future<void> _editString({
    required String title,
    required String initial,
    required String hint,
    required Future<void> Function(String) onSubmit,
  }) async {
    final ctrl = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null) await onSubmit(result);
  }

  Future<void> _editSecret({
    required String title,
    required bool isUrl,
    required bool isRtl,
    required Future<void> Function(String?) onSubmit,
  }) async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          obscureText: !isUrl,
          keyboardType: isUrl ? TextInputType.url : TextInputType.visiblePassword,
          decoration: InputDecoration(
            hintText: isUrl
                ? 'http://localhost:11434'
                : (isRtl ? 'ألصق المفتاح هنا' : 'Paste key here'),
            helperText: isUrl
                ? null
                : (isRtl
                    ? 'يُخزّن في Keystore / Keychain — لا يُعرض ولا يُسجَّل'
                    : 'Stored in Keystore / Keychain — never displayed, never logged'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) await onSubmit(result);
  }

  Future<void> _downloadModel(String modelId, bool isRtl) async {
    setState(() {
      _downloading = true;
      _downloadProgress = 0;
      _downloadStatus = isRtl ? 'بدء التنزيل' : 'Starting download';
    });
    try {
      await OnDeviceLlm.downloadModel(
        modelId,
        onProgress: (p) {
          if (mounted) {
            setState(() {
              _downloadProgress = p;
              _downloadStatus = null;
            });
          }
        },
      );
      if (!mounted) return;
      await context.read<ScrapingProvider>().markOnDeviceModelReady();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isRtl ? 'تم التنزيل بنجاح' : 'Downloaded')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${isRtl ? "فشل" : "Failed"}: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _downloading = false;
          _downloadProgress = 0;
          _downloadStatus = null;
        });
      }
    }
  }

  Future<void> _confirmDeleteModel(bool isRtl) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isRtl ? 'حذف النموذج؟' : 'Delete model?'),
        content: Text(isRtl
            ? 'سيُحذف ملف النموذج من جهازك. يمكن إعادة تنزيله لاحقاً.'
            : 'This deletes the model file from your device. You can re-download later.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    // Unload from RAM if loaded.
    await OnDeviceLlm.instance.unload();

    // Delete the model file from disk.
    final path = await Secrets.instance.getOnDeviceModelPath();
    if (path != null) {
      try {
        final f = File(path);
        if (f.existsSync()) await f.delete();
      } catch (_) {}
    }
    // Clear the pointers in secure storage (API keys are NOT touched).
    await Secrets.instance.setOnDeviceModelPath(null);
    await Secrets.instance.setOnDeviceModelName(null);
    // Force a refresh of cached flags.
    await context.read<ScrapingProvider>().markOnDeviceModelReady();
    // Force re-read of the model name next build.
    _storedModelNameFuture = null;

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(isRtl ? 'تم حذف النموذج' : 'Model deleted')),
    );
  }

  Future<void> _confirmForgetAll(bool isRtl) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isRtl ? 'مسح كل المفاتيح؟' : 'Forget all keys?'),
        content: Text(isRtl
            ? 'يحذف كل مفاتيح الـ API من المخزن الآمن. لا يمكن التراجع.'
            : 'Wipes every API key from secure storage. Cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Forget'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await context.read<ScrapingProvider>().forgetAllSecrets();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(isRtl ? 'تم المسح' : 'Forgotten')),
    );
  }
}

class _Section extends StatelessWidget {
  final String text;
  const _Section(this.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: isDark
              ? theme.colorScheme.secondary
              : theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
