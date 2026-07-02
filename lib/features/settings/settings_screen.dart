import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/currencies.dart';
import '../../core/database/dao/item_dao.dart';
import '../../core/database/dao/store_dao.dart';
import '../../core/providers/currency_provider.dart';
import '../../core/providers/locale_provider.dart';
import '../../core/providers/scraping_provider.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/providers/user_provider.dart';
import '../../core/services/backup_service.dart';
import '../../core/services/share_service.dart';
import 'category_settings_screen.dart';
import 'llm_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _busy = false;
  String _appVersion = 'Loading...';

  @override
  void initState() {
    super.initState();
    _initPackageInfo();
  }

  Future<void> _initPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = info.version;
    });
  }

  Future<void> _changeUsername() async {
    final userProv = context.read<UserProvider>();
    final ctrl = TextEditingController(text: userProv.username ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          context.read<LocaleProvider>().isRtl
              ? 'تغيير اسم المستخدم'
              : 'Change username',
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Username'),
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
    if (result != null && result.isNotEmpty) {
      await userProv.set(result);
    }
  }

  Future<void> _pickLanguage() async {
    final locale = context.read<LocaleProvider>();
    final isRtl = locale.isRtl;
    await showDialog<void>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(isRtl ? 'اللغة' : 'Language'),
        children: [
          SimpleDialogOption(
            onPressed: () {
              locale.set(const Locale('en'));
              Navigator.pop(ctx);
            },
            child: const Text('English'),
          ),
          SimpleDialogOption(
            onPressed: () {
              locale.set(const Locale('ar'));
              Navigator.pop(ctx);
            },
            child: const Text('العربية', textDirection: TextDirection.rtl),
          ),
        ],
      ),
    );
  }

  Future<void> _pickTheme() async {
    final themeProv = context.read<ThemeProvider>();
    final locale = context.read<LocaleProvider>();
    final isRtl = locale.isRtl;
    await showDialog<void>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(isRtl ? 'السمة' : 'Theme'),
        children: [
          SimpleDialogOption(
            onPressed: () {
              themeProv.set(ThemeMode.light);
              Navigator.pop(ctx);
            },
            child: Text(isRtl ? 'فاتح' : 'Light'),
          ),
          SimpleDialogOption(
            onPressed: () {
              themeProv.set(ThemeMode.dark);
              Navigator.pop(ctx);
            },
            child: Text(isRtl ? 'داكن' : 'Dark'),
          ),
          SimpleDialogOption(
            onPressed: () {
              themeProv.set(ThemeMode.system);
              Navigator.pop(ctx);
            },
            child: Text(isRtl ? 'النظام' : 'System'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickCurrency() async {
    final currencyProv = context.read<CurrencyProvider>();
    final locale = context.read<LocaleProvider>();
    final isRtl = locale.isRtl;
    await showDialog<void>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(isRtl ? 'اختر العملة' : 'Select Currency'),
        children: [
          SimpleDialogOption(
            onPressed: () {
              currencyProv.set(AppCurrency.sar);
              Navigator.pop(ctx);
            },
            child: const Text('Saudi Riyal (﷼)'),
          ),
          SimpleDialogOption(
            onPressed: () {
              currencyProv.set(AppCurrency.usd);
              Navigator.pop(ctx);
            },
            child: const Text('US Dollar (\$)'),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── Data actions ──────────────────────────
  Future<void> _backup() async {
    setState(() => _busy = true);
    try {
      // SECURITY (Finding 5): Ask the user for an optional passphrase.
      // If provided, the backup ZIP is encrypted with AES-256-GCM.
      // If cancelled, the user wants a plain backup.
      // If "skip" is tapped (empty passphrase), we proceed without encryption.
      final passphrase = await _askForPassphrase(isRtl: context.read<LocaleProvider>().isRtl);
      if (passphrase == null) {
        // User cancelled the entire backup.
        setState(() => _busy = false);
        return;
      }
      final zip = await BackupService.instance.createBackup(
        passphrase: passphrase.isEmpty ? null : passphrase,
      );
      if (!mounted) return;
      // share_plus 12+ deprecates Share.shareXFiles in favor of
      // SharePlus.instance.share(ShareParams(...)). Using the new API.
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(zip.path)],
          text: 'Bazaar backup ${DateTime.now().toIso8601String()}',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _snack('Backup failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Returns:
  ///   null  = user cancelled the entire backup
  ///   ""    = user wants a plaintext (unencrypted) backup
  ///   "..." = user wants an encrypted backup with this passphrase
  Future<String?> _askForPassphrase({required bool isRtl}) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isRtl ? 'تأمين النسخة الاحتياطية' : 'Backup passphrase'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isRtl
                  ? 'أدخل عبارة مرور لتشفير النسخة (اختياري). اتركها فارغة لنسخة غير مشفّرة.'
                  : 'Enter a passphrase to encrypt the backup (optional). '
                      'Leave empty for a plaintext backup.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false,
              keyboardType: TextInputType.visiblePassword,
              decoration: InputDecoration(
                hintText: isRtl ? 'عبارة المرور' : 'Passphrase',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: Text(isRtl ? 'إلغاء' : 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ''),
            child: Text(isRtl ? 'بدون تشفير' : 'No encryption'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: Text(isRtl ? 'تشفير' : 'Encrypt'),
          ),
        ],
      ),
    );
  }

  /// Prompt the user for the passphrase to decrypt an encrypted backup.
  /// Returns null if the user cancels.
  Future<String?> _askForRestorePassphrase({required bool isRtl}) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isRtl ? 'فك تشفير النسخة' : 'Decrypt backup'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isRtl
                  ? 'هذه النسخة محمية بعبارة مرور. أدخلها للاستعادة.'
                  : 'This backup is encrypted. Enter the passphrase to restore it.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false,
              keyboardType: TextInputType.visiblePassword,
              decoration: InputDecoration(
                hintText: isRtl ? 'عبارة المرور' : 'Passphrase',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: Text(isRtl ? 'إلغاء' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: Text(isRtl ? 'فك التشفير' : 'Decrypt'),
          ),
        ],
      ),
    );
  }

  Future<void> _restore() async {
    setState(() => _busy = true);
    try {
      final locale = context.read<LocaleProvider>();
      final isRtl = locale.isRtl;
      final contents = await BackupService.instance.pickAndRead(
        passphrasePrompt: () => _askForRestorePassphrase(isRtl: isRtl),
      );
      if (contents == null) {
        setState(() => _busy = false);
        return;
      }
      if (!mounted) return;
      final restoreItems = ValueNotifier<bool>(true);
      final restoreStores = ValueNotifier<bool>(true);
      final restoreLists = ValueNotifier<bool>(true);

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title:
              Text(isRtl ? 'اختر ما تريد استعادته' : 'Select what to restore'),
          content: StatefulBuilder(
            builder: (ctx, setS) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ValueListenableBuilder<bool>(
                    valueListenable: restoreItems,
                    builder: (_, v, __) => CheckboxListTile(
                      value: v,
                      title: Text(
                        '${isRtl ? "منتجات" : "Items"} (${contents.itemsCount})',
                      ),
                      onChanged: (b) {
                        restoreItems.value = b ?? false;
                        setS(() {});
                      },
                    ),
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: restoreStores,
                    builder: (_, v, __) => CheckboxListTile(
                      value: v,
                      title: Text(
                        '${isRtl ? "متاجر" : "Stores"} (${contents.storesCount})',
                      ),
                      onChanged: (b) {
                        restoreStores.value = b ?? false;
                        setS(() {});
                      },
                    ),
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: restoreLists,
                    builder: (_, v, __) => CheckboxListTile(
                      value: v,
                      title: Text(
                        '${isRtl ? "قوائم" : "Lists"} (${contents.listsCount})',
                      ),
                      onChanged: (b) {
                        restoreLists.value = b ?? false;
                        setS(() {});
                      },
                    ),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(isRtl ? 'إلغاء' : 'Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(isRtl ? 'استعادة' : 'Restore'),
            ),
          ],
        ),
      );
      if (confirmed != true) {
        setState(() => _busy = false);
        return;
      }
      final summary = await BackupService.instance.restoreSelective(
        contents,
        restoreItems: restoreItems.value,
        restoreStores: restoreStores.value,
        restoreLists: restoreLists.value,
      );
      if (!mounted) return;
      _snack(
        isRtl
            ? 'اكتملت الاستعادة: ${summary.items} منتج، ${summary.stores} متجر، ${summary.lists} قائمة'
                '${summary.skipped > 0 ? " (تم تخطّي ${summary.skipped})" : ""}'
            : 'Restore complete: ${summary.items} items, ${summary.stores} stores, ${summary.lists} lists'
                '${summary.skipped > 0 ? " (${summary.skipped} skipped)" : ""}',
      );
    } catch (e) {
      if (!mounted) return;
      _snack('Restore failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    setState(() => _busy = true);
    try {
      final summary = await ShareService.instance.importFromFile();
      if (summary.cancelled) {
        setState(() => _busy = false);
        return;
      }
      if (!mounted) return;
      final locale = context.read<LocaleProvider>();
      _snack(
        locale.isRtl
            ? 'اكتمل الاستيراد: ${summary.count} عنصر (${summary.type})'
            : 'Import complete: ${summary.count} (${summary.type})',
      );
    } catch (e) {
      if (!mounted) return;
      _snack('Import failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportItems() async {
    setState(() => _busy = true);
    try {
      await ShareService.instance.exportItems(await ItemDao.instance.all());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportStores() async {
    setState(() => _busy = true);
    try {
      await ShareService.instance.exportStores(await StoreDao.instance.all());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final themeProv = context.watch<ThemeProvider>();
    final currencyProv = context.watch<CurrencyProvider>();
    final userProv = context.watch<UserProvider>();
    // Watch scraping provider so the subtitle updates live when strategy changes.
    final scraping = context.watch<ScrapingProvider>();
    final isRtl = locale.isRtl;

    // Build a short status line for the search/AI tile.
    final strategyLabel =
        scraping.strategy.displayName(isRtl ? 'ar' : 'en');
    final configOk = scraping.isConfigComplete;
    final statusText = configOk
        ? strategyLabel
        : (isRtl
            ? 'غير مكتمل — اضغط للإعداد'
            : 'Incomplete — tap to configure');

    return Scaffold(
      appBar: AppBar(title: Text(isRtl ? 'الإعدادات' : 'Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.category_outlined),
            title: Text(isRtl ? 'تصنيفات المنتجات' : 'Item Categories'),
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const CategorySettingsScreen(),
                ),
              );
            },
          ),

          // ─────────────────────────────────────────────────────────────
          // NEW: Search & AI settings entry point
          // ─────────────────────────────────────────────────────────────
          const Divider(),
          _SectionHeader(isRtl ? 'البحث والذكاء الاصطناعي' : 'Search & AI'),
          ListTile(
            leading: Icon(
              configOk ? Icons.psychology : Icons.psychology_outlined,
              color: configOk
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.error,
            ),
            title: Text(isRtl
                ? 'إعدادات البحث و LLM'
                : 'Search & LLM settings'),
            subtitle: Text(
              statusText,
              style: TextStyle(
                color: configOk ? null : Theme.of(context).colorScheme.error,
              ),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const LlmSettingsScreen(),
                ),
              );
            },
          ),

          const Divider(),
          _SectionHeader(isRtl ? 'عام' : 'General'),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(isRtl ? 'اسم المستخدم' : 'Username'),
            subtitle: Text(userProv.username ?? '—'),
            onTap: _changeUsername,
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(isRtl ? 'اللغة' : 'Language'),
            subtitle: Text(isRtl ? 'العربية' : 'English'),
            onTap: _pickLanguage,
          ),
          ListTile(
            leading:
                Icon(themeProv.isDark ? Icons.dark_mode : Icons.light_mode),
            title: Text(isRtl ? 'السمة' : 'Theme'),
            subtitle: Text(
              themeProv.isDark
                  ? (isRtl ? 'داكن' : 'Dark')
                  : (isRtl ? 'فاتح' : 'Light'),
            ),
            onTap: _pickTheme,
          ),
          ListTile(
            leading: const Icon(Icons.attach_money),
            title: Text(isRtl ? 'العملة' : 'Currency'),
            subtitle: Text(
              currencyProv.currency == AppCurrency.sar
                  ? 'Saudi Riyal (﷼)'
                  : 'US Dollar (\$)',
            ),
            onTap: _pickCurrency,
          ),
          const Divider(),
          _SectionHeader(isRtl ? 'إدارة البيانات' : 'Data Management'),
          ListTile(
            leading: _busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.backup_outlined),
            title: Text(isRtl ? 'نسخ احتياطي' : 'Backup'),
            subtitle: Text(
              isRtl ? 'أنشئ ملف zip وشاركه' : 'Create a zip file and share it',
            ),
            onTap: _busy ? null : _backup,
          ),
          ListTile(
            leading: _busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.restore),
            title: Text(isRtl ? 'استعادة' : 'Restore'),
            subtitle: Text(
              isRtl
                  ? 'اختر ملف zip للاستعادة'
                  : 'Pick a zip file to restore from',
            ),
            onTap: _busy ? null : _restore,
          ),
          ListTile(
            leading: _busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download),
            title: Text(isRtl ? 'استيراد JSON' : 'Import JSON'),
            subtitle: Text(
              isRtl
                  ? 'استيراد منتجات/قوائم/متاجر'
                  : 'Import items / lists / stores',
            ),
            onTap: _busy ? null : _import,
          ),
          ListTile(
            leading: const Icon(Icons.upload),
            title: Text(isRtl ? 'تصدير المنتجات' : 'Export Items'),
            onTap: _busy ? null : _exportItems,
          ),
          ListTile(
            leading: const Icon(Icons.upload),
            title: Text(isRtl ? 'تصدير المتاجر' : 'Export Stores'),
            onTap: _busy ? null : _exportStores,
          ),
          const Divider(),
          _SectionHeader(isRtl ? 'حول' : 'About'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(isRtl ? 'الإصدار' : 'Version'),
            subtitle: Text(_appVersion),
          ),
          ListTile(
            leading: const Icon(Icons.code),
            title: Text(
              isRtl ? 'بازار — تطبيق محلي بالكامل' : 'Bazaar — fully local app',
            ),
            subtitle: Text(
              isRtl
                  ? 'لا خادم، لا حساب، خصوصية كاملة'
                  : 'No server, no account, full privacy',
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
