import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/currencies.dart';
import '../../core/design/app_dimens.dart';
import '../../core/design/components/section_header.dart';
import '../../core/models/models.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/settings_providers.dart';
import '../../core/services/scraping_config.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../core/router/app_router.dart';

/// Settings hub: general, search & AI, data (backup/restore/export/import),
/// and about.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l.settingsTitle)),
      body: ListView(
        padding: AppDimens.pagePadding.copyWith(bottom: 32),
        children: [
          SectionHeader(
            l.settingsGeneral,
            padding: const EdgeInsets.fromLTRB(4, 8, 0, 4),
          ),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(l.username),
                  subtitle: Text(ref.watch(userProvider) ?? '—'),
                  onTap: () => _changeUsername(context, ref),
                ),
                ListTile(
                  leading: const Icon(Icons.language),
                  title: Text(l.language),
                  subtitle: Text(
                    ref.watch(localeProvider)?.languageCode == 'ar'
                        ? 'العربية'
                        : 'English',
                  ),
                  onTap: () => _pickLanguage(context, ref),
                ),
                ListTile(
                  leading: const Icon(Icons.dark_mode_outlined),
                  title: Text(l.theme),
                  subtitle: Text(switch (ref.watch(themeProvider)) {
                    ThemeMode.light => l.themeLight,
                    ThemeMode.dark => l.themeDark,
                    ThemeMode.system => l.themeSystem,
                  }),
                  onTap: () => _pickTheme(context, ref),
                ),
                ListTile(
                  leading: const Icon(Icons.currency_exchange),
                  title: Text(l.currency),
                  subtitle: Text(
                    ref.watch(currencyProvider) == AppCurrency.sar
                        ? l.sarCurrency
                        : l.usdCurrency,
                  ),
                  onTap: () => _pickCurrency(context, ref),
                ),
                ListTile(
                  leading: const Icon(Icons.category_outlined),
                  title: Text(l.manageCategories),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () => context.push(Routes.categories),
                ),
              ],
            ),
          ),

          SectionHeader(
            l.settingsSearch,
            padding: const EdgeInsets.fromLTRB(4, 16, 0, 4),
          ),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.travel_explore),
                  title: Text(l.searchAndAiTitle),
                  subtitle: Text(l.searchAndAiHint),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () => context.push(Routes.llmSettings),
                ),
                Consumer(
                  builder: (context, ref, _) {
                    final config = ref.watch(scrapingConfigProvider);
                    final presence =
                        ref.watch(keyPresenceProvider).value ??
                        const KeyPresence.empty();
                    final complete = config.isConfigComplete(presence);
                    return ListTile(
                      leading: Icon(
                        complete
                            ? Icons.verified_outlined
                            : Icons.error_outline,
                      ),
                      iconColor: complete
                          ? theme.colorScheme.secondary
                          : theme.colorScheme.error,
                      title: Text(
                        complete ? l.configComplete : l.configIncomplete,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          SectionHeader(
            l.settingsData,
            padding: const EdgeInsets.fromLTRB(4, 16, 0, 4),
          ),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.backup_outlined),
                  title: Text(l.createBackup),
                  subtitle: Text(
                    l.backupHint,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => _createBackup(context, ref),
                ),
                ListTile(
                  leading: const Icon(Icons.restore),
                  title: Text(l.restoreBackup),
                  onTap: () => _restore(context, ref),
                ),
                ListTile(
                  leading: const Icon(Icons.ios_share),
                  title: Text(l.exportItems),
                  onTap: () async {
                    final db = ref.read(databaseProvider);
                    final rows = await db.itemDao.all();
                    // ignore: use_build_context_synchronously
                    await ref
                        .read(shareServiceProvider)
                        .exportItems(rows.map((r) => Item.fromRow(r)).toList());
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.store_outlined),
                  title: Text(l.exportStores),
                  onTap: () async {
                    final db = ref.read(databaseProvider);
                    final rows = await db.storeDao.all();
                    // ignore: use_build_context_synchronously
                    await ref
                        .read(shareServiceProvider)
                        .exportStores(
                          rows.map((r) => Store.fromRow(r)).toList(),
                        );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.download_for_offline_outlined),
                  title: Text(l.importData),
                  onTap: () => _importJson(context, ref),
                ),
              ],
            ),
          ),

          SectionHeader(
            l.settingsAbout,
            padding: const EdgeInsets.fromLTRB(4, 16, 0, 4),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppDimens.space4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FutureBuilder<PackageInfo>(
                    future: PackageInfo.fromPlatform(),
                    builder: (context, snap) => Text(
                      '${l.aboutVersion} ${snap.data?.version ?? '…'}',
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  const SizedBox(height: AppDimens.space2),
                  Text(
                    l.appTagline,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: AppDimens.space2),
                  Text(
                    l.aboutPrivacy,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppDimens.space2),
                  Text(
                    l.aboutLicense,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Dialogs ─────────────────────────────────────────────────────────────
  Future<void> _changeUsername(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: ref.read(userProvider));
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.changeUsername),
        content: TextField(
          controller: controller,
          autofocus: true,
          onSubmitted: (v) => Navigator.of(context).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(l.commonSave),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null) return;
    await ref.read(userProvider.notifier).set(name.trim());
  }

  Future<void> _pickLanguage(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context)!;
    final current = ref.read(localeProvider)?.languageCode;
    final chosen = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l.language),
        children: [
          for (final entry in {'en': 'English', 'ar': 'العربية'}.entries)
            RadioListTile<String>(
              value: entry.key,
              groupValue: current,
              title: Text(entry.value),
              onChanged: (v) => Navigator.of(context).pop(v),
            ),
        ],
      ),
    );
    if (chosen == null) return;
    await ref.read(localeProvider.notifier).set(Locale(chosen));
  }

  Future<void> _pickTheme(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context)!;
    final current = ref.read(themeProvider);
    final chosen = await showDialog<ThemeMode>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l.theme),
        children: [
          for (final mode in [
            (ThemeMode.system, l.themeSystem),
            (ThemeMode.light, l.themeLight),
            (ThemeMode.dark, l.themeDark),
          ])
            RadioListTile<ThemeMode>(
              value: mode.$1,
              groupValue: current,
              title: Text(mode.$2),
              onChanged: (v) => Navigator.of(context).pop(v),
            ),
        ],
      ),
    );
    if (chosen == null) return;
    await ref.read(themeProvider.notifier).set(chosen);
  }

  Future<void> _pickCurrency(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context)!;
    final current = ref.read(currencyProvider);
    final chosen = await showDialog<AppCurrency>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l.currency),
        children: [
          RadioListTile<AppCurrency>(
            value: AppCurrency.sar,
            groupValue: current,
            title: Text(l.sarCurrency),
            onChanged: (v) => Navigator.of(context).pop(v),
          ),
          RadioListTile<AppCurrency>(
            value: AppCurrency.usd,
            groupValue: current,
            title: Text(l.usdCurrency),
            onChanged: (v) => Navigator.of(context).pop(v),
          ),
        ],
      ),
    );
    if (chosen == null) return;
    await ref.read(currencyProvider.notifier).set(chosen);
  }

  // ── Data actions ────────────────────────────────────────────────────────
  Future<void> _createBackup(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final passphrase = await _askPassphrase(context, optional: true);
    if (passphrase == null) return; // cancelled
    try {
      final file = await ref
          .read(backupServiceProvider)
          .createBackup(passphrase: passphrase.isEmpty ? null : passphrase);
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], text: l.backupCreated),
      );
      messenger.showSnackBar(SnackBar(content: Text(l.backupCreated)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('${l.backupFailed}: $e')));
    }
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final contents = await ref
          .read(backupServiceProvider)
          .pickAndRead(
            passphrasePrompt: () => _askPassphrase(context, optional: false),
          );
      if (contents == null) return;
      final summary = await ref
          .read(backupServiceProvider)
          .restoreSelective(contents);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l.restoreComplete(
              summary.items,
              summary.stores,
              summary.lists,
              summary.skipped,
            ),
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('${l.restoreFailed}: $e')));
    }
  }

  Future<void> _importJson(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final summary = await ref.read(shareServiceProvider).importFromFile();
      if (summary.cancelled) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l.importComplete(summary.count))),
      );
    } on FormatException {
      messenger.showSnackBar(SnackBar(content: Text(l.importUnknownType)));
    } on StateError catch (e) {
      if (e.message.contains('too large')) {
        messenger.showSnackBar(SnackBar(content: Text(l.importTooLarge)));
      } else {
        messenger.showSnackBar(
          SnackBar(content: Text('${l.importFailed}: $e')),
        );
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('${l.importFailed}: $e')));
    }
  }

  /// Returns '' for skip-encryption, a passphrase, or null when cancelled.
  Future<String?> _askPassphrase(
    BuildContext context, {
    required bool optional,
  }) async {
    final l = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.backupPassphrase),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (optional)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(l.backupPassphraseHint),
              ),
            TextField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              onSubmitted: (v) => Navigator.of(context).pop(v),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(l.continueLabel),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }
}
