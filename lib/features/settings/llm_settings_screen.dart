import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/app_dimens.dart';
import '../../core/design/components/section_header.dart';
import '../../core/design/components/status_chip.dart';
import '../../core/providers/settings_providers.dart';
import '../../core/services/llm_extractor.dart' show LlmProvider, LlmProviderX;
import '../../core/services/on_device_llm.dart';
import '../../core/services/scraping_config.dart';
import '../../core/services/secrets.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../core/router/app_router.dart';

/// Search & AI settings: extraction strategy, cloud provider + keys,
/// SearXNG server, and the on-device model manager.
class LlmSettingsScreen extends ConsumerStatefulWidget {
  const LlmSettingsScreen({super.key});

  @override
  ConsumerState<LlmSettingsScreen> createState() => _LlmSettingsScreenState();
}

class _LlmSettingsScreenState extends ConsumerState<LlmSettingsScreen> {
  double? _downloadProgress;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final config = ref.watch(scrapingConfigProvider);
    final presence =
        ref.watch(keyPresenceProvider).value ?? const KeyPresence.empty();

    return Scaffold(
      appBar: AppBar(
        title: Text(l.searchAndAiTitle),
        actions: [
          IconButton(
            tooltip: l.pipelineDebugger,
            icon: const Icon(Icons.bug_report_outlined),
            onPressed: () => context.push(Routes.pipelineDebugger),
          ),
        ],
      ),
      body: ListView(
        padding: AppDimens.pagePadding.copyWith(bottom: 32),
        children: [
          // ── Status ────────────────────────────────────────────────────
          StatusChip(
            icon: config.isConfigComplete(presence)
                ? Icons.check_circle_outline
                : Icons.error_outline,
            label: config.isConfigComplete(presence)
                ? l.configComplete
                : l.configIncomplete,
            color: config.isConfigComplete(presence)
                ? theme.colorScheme.secondary
                : theme.colorScheme.error,
          ),

          // ── Strategy ──────────────────────────────────────────────────
          SectionHeader(l.extractionStrategy),
          Card(
            child: Column(
              children: [
                for (final s in ExtractionStrategy.values)
                  RadioListTile<ExtractionStrategy>(
                    value: s,
                    groupValue: config.strategy,
                    title: Text(switch (s) {
                      ExtractionStrategy.schemaOnly => l.strategySchemaOnly,
                      ExtractionStrategy.schemaThenCloudLlm =>
                        l.strategySchemaCloud,
                      ExtractionStrategy.schemaThenOnDevice =>
                        l.strategySchemaOnDevice,
                      ExtractionStrategy.schemaCloudOnDevice =>
                        l.strategySchemaCloudOnDevice,
                      ExtractionStrategy.cloudLlmOnly => l.strategyCloudOnly,
                      ExtractionStrategy.onDeviceOnly => l.strategyOnDeviceOnly,
                    }),
                    onChanged: (v) => _update(config.copyWith(strategy: v)),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 0, 0),
            child: Text(
              l.strategyHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),

          // ── SearXNG ───────────────────────────────────────────────────
          SectionHeader(l.searxngUrlField),
          Card(
            child: ListTile(
              leading: const Icon(Icons.dns_outlined),
              title: Text(
                config.searxngUrl.isEmpty
                    ? l.searxngUrlHint
                    : config.searxngUrl,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.edit_outlined, size: 20),
              onTap: () => _editSearxngUrl(config),
            ),
          ),

          // ── Cloud provider ────────────────────────────────────────────
          SectionHeader(l.cloudProvider),
          Card(
            child: Column(
              children: [
                for (final p in LlmProvider.values)
                  RadioListTile<LlmProvider>(
                    value: p,
                    groupValue: config.provider,
                    title: Text(switch (p) {
                      LlmProvider.gemini => l.providerGemini,
                      LlmProvider.openai => l.providerOpenai,
                      LlmProvider.groq => l.providerGroq,
                      LlmProvider.cerebras => l.providerCerebras,
                      LlmProvider.ollama => l.providerOllama,
                    }),
                    secondary: StatusChip(
                      icon: p == LlmProvider.ollama
                          ? (presence.ollamaBaseUrl ? Icons.check : Icons.close)
                          : (presence.forProvider(p)
                                ? Icons.check
                                : Icons.close),
                      label: p == LlmProvider.ollama
                          ? (presence.ollamaBaseUrl
                                ? l.apiKeySet
                                : l.apiKeyMissing)
                          : (presence.forProvider(p)
                                ? l.apiKeySet
                                : l.apiKeyMissing),
                      color:
                          (p == LlmProvider.ollama
                              ? presence.ollamaBaseUrl
                              : presence.forProvider(p))
                          ? theme.colorScheme.secondary
                          : theme.colorScheme.error,
                    ),
                    onChanged: (v) => _update(
                      config.copyWith(provider: v, model: '', baseUrl: ''),
                    ),
                  ),
              ],
            ),
          ),

          // ── API key / model / base URL ────────────────────────────────
          if (config.provider.needsApiKey)
            Card(
              child: ListTile(
                leading: Icon(
                  presence.forProvider(config.provider)
                      ? Icons.key
                      : Icons.key_off_outlined,
                ),
                title: Text(l.apiKeyField),
                subtitle: Text(
                  l.apiKeyHint,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: FilledButton.tonal(
                  onPressed: () => _editApiKey(config),
                  child: Text(l.commonEdit),
                ),
              ),
            ),
          if (config.provider == LlmProvider.ollama)
            Card(
              child: ListTile(
                leading: const Icon(Icons.computer_outlined),
                title: Text(l.ollamaBaseUrlField),
                subtitle: Text(
                  presence.ollamaBaseUrl ? l.apiKeySet : l.providerOllama,
                ),
                trailing: FilledButton.tonal(
                  onPressed: () => _editOllamaBaseUrl(),
                  child: Text(l.commonEdit),
                ),
              ),
            ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.memory_outlined),
              title: Text(l.modelField),
              subtitle: Text(config.model.isEmpty ? l.modelHint : config.model),
              trailing: const Icon(Icons.edit_outlined, size: 20),
              onTap: () => _editModel(config),
            ),
          ),

          // ── On-device model ───────────────────────────────────────────
          SectionHeader(l.onDeviceModels),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppDimens.space4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.onDeviceHint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppDimens.space3),
                  for (final model in OnDeviceLlm.preset)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppDimens.space2),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              model.name,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                          FutureBuilder<bool>(
                            future: OnDeviceLlm.isModelDownloaded(model.id),
                            builder: (context, snap) {
                              final downloaded = snap.data ?? false;
                              return FilledButton.tonal(
                                onPressed: _downloadProgress != null
                                    ? null
                                    : (downloaded
                                          ? () => _deleteModel(
                                              context,
                                              ref,
                                              model,
                                            )
                                          : () => _downloadModel(
                                              model.id,
                                              config,
                                            )),
                                child: Text(
                                  downloaded ? l.deleteModel : l.downloadModel,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  if (_downloadProgress != null) ...[
                    const SizedBox(height: AppDimens.space2),
                    Text(
                      l.downloadingModel((_downloadProgress! * 100).round()),
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(value: _downloadProgress),
                  ],
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      l.autoloadOnDevice,
                      style: theme.textTheme.bodyMedium,
                    ),
                    value: config.autoLoadOnDevice,
                    onChanged: (v) =>
                        _update(config.copyWith(autoLoadOnDevice: v)),
                  ),
                ],
              ),
            ),
          ),

          // ── Danger zone ───────────────────────────────────────────────
          const SizedBox(height: AppDimens.space4),
          Card(
            child: ListTile(
              leading: Icon(Icons.key_off, color: theme.colorScheme.error),
              title: Text(l.forgetAllKeys),
              onTap: () => _forgetKeys(context, ref),
            ),
          ),
        ],
      ),
    );
  }

  // ── helpers ─────────────────────────────────────────────────────────────
  Future<void> _update(ScrapingConfig config) async {
    try {
      await ref.read(scrapingConfigProvider.notifier).update(config);
    } on ArgumentError {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.invalidUrl)),
        );
      }
    }
  }

  Future<void> _editSearxngUrl(ScrapingConfig config) async {
    final l = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: config.searxngUrl);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.searxngUrlField),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(hintText: l.searxngUrlHint),
          onSubmitted: (v) => Navigator.of(context).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(l.commonSave),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return;
    try {
      ScrapingConfig.validateSearxngUrl(value);
    } on ArgumentError {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.invalidUrl)));
      }
      return;
    }
    await _update(config.copyWith(searxngUrl: value));
  }

  Future<void> _editApiKey(ScrapingConfig config) async {
    final l = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.apiKeyField),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          onSubmitted: (v) => Navigator.of(context).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(l.commonSave),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return;
    final secrets = Secrets.instance;
    switch (config.provider) {
      case LlmProvider.gemini:
        await secrets.setGeminiKey(value);
      case LlmProvider.openai:
        await secrets.setOpenAiKey(value);
      case LlmProvider.groq:
        await secrets.setGroqKey(value);
      case LlmProvider.cerebras:
        await secrets.setCerebrasKey(value);
      case LlmProvider.ollama:
        break;
    }
    await ref.read(keyPresenceProvider.notifier).refresh();
  }

  Future<void> _editOllamaBaseUrl() async {
    final l = AppLocalizations.of(context)!;
    final current = await Secrets.instance.getOllamaBaseUrl();
    final controller = TextEditingController(text: current ?? '');
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.ollamaBaseUrlField),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            hintText: 'http://localhost:11434/v1',
          ),
          onSubmitted: (v) => Navigator.of(context).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(l.commonSave),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return;
    await Secrets.instance.setOllamaBaseUrl(value);
    await ref.read(keyPresenceProvider.notifier).refresh();
  }

  Future<void> _editModel(ScrapingConfig config) async {
    final l = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: config.model);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.modelField),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: l.modelHint),
          onSubmitted: (v) => Navigator.of(context).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(l.commonSave),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return;
    await _update(config.copyWith(model: value));
  }

  Future<void> _downloadModel(String modelId, ScrapingConfig config) async {
    try {
      final path = await OnDeviceLlm.downloadModel(
        modelId,
        onProgress: (p) {
          if (mounted) setState(() => _downloadProgress = p);
        },
      );
      // Register the file with the MediaPipe runtime (idempotent).
      await OnDeviceLlm.registerDownloadedModel();
      debugPrint('On-device model saved: $path');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _downloadProgress = null);
      await ref.read(keyPresenceProvider.notifier).refresh();
    }
  }

  Future<void> _deleteModel(
    BuildContext context,
    WidgetRef ref,
    OnDeviceModel model,
  ) async {
    final path = await OnDeviceLlm.modelFilePath(model.id);
    final f = File(path);
    if (f.existsSync()) await f.delete();
    await Secrets.instance.setOnDeviceModelPath(null);
    await Secrets.instance.setOnDeviceModelName(null);
    await ref.read(keyPresenceProvider.notifier).refresh();
  }

  Future<void> _forgetKeys(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.forgetAllKeys),
        content: Text(l.forgetAllKeysConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.commonConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await Secrets.instance.clearAll();
    await ref.read(keyPresenceProvider.notifier).refresh();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.keysForgotten)));
    }
  }
}
