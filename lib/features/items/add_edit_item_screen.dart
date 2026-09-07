import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/currencies.dart';
import '../../core/database/app_database.dart';
import '../../core/models/models.dart';
import '../../core/database/daos/item_dao.dart';
import '../../core/design/app_dimens.dart';
import '../../core/design/components/app_image.dart';
import '../../core/design/components/price_text.dart';
import '../../core/design/components/section_header.dart';
import '../../core/providers/data_providers.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/settings_providers.dart';
import '../../core/router/app_router.dart';
import '../../core/services/scraping_config.dart';
import '../../l10n/generated/app_localizations.dart';

/// Add/Edit item — three tabs (General / Prices / History).
///
/// v2 fixes: the Arabic name is actually persisted (v1 always wrote null),
/// controllers are disposed correctly, per-store price edits preserve
/// history, and the online lookup runs against the chosen source.
class AddEditItemScreen extends ConsumerStatefulWidget {
  final int? itemId;
  final String? barcode;

  const AddEditItemScreen({super.key, this.itemId, this.barcode});

  @override
  ConsumerState<AddEditItemScreen> createState() => _AddEditItemScreenState();
}

class _AddEditItemScreenState extends ConsumerState<AddEditItemScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);

  final _formKey = GlobalKey<FormState>();
  final _nameEn = TextEditingController();
  final _nameAr = TextEditingController();
  final _brand = TextEditingController();
  final _barcode = TextEditingController();
  final _note = TextEditingController();
  final _imageUrl = TextEditingController();

  int? _categoryId;
  String? _localImagePath;
  bool _loading = true;
  bool _saving = false;
  bool _lookingUp = false;

  final _priceControllers = <int, TextEditingController>{};
  final _activeStores = <int>{};
  ItemRow? _existing;

  @override
  void initState() {
    super.initState();
    if (widget.barcode != null) _barcode.text = widget.barcode!;
    _load();
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    if (widget.itemId != null) {
      final row = await db.itemDao.findById(widget.itemId!);
      if (row != null) {
        _existing = row;
        _nameEn.text = row.nameEn;
        _nameAr.text = row.nameAr ?? '';
        _brand.text = row.brand ?? '';
        _barcode.text = row.barcode ?? '';
        _note.text = row.note ?? '';
        _imageUrl.text = row.imageUrl ?? '';
        _categoryId = row.categoryId;
        final prices = await db.itemStoreDao.forItem(row.id);
        final stores = await db.storeDao.all();
        final storeById = {for (final s in stores) s.id: s};
        for (final p in prices) {
          if (storeById.containsKey(p.storeId)) {
            _activeStores.add(p.storeId);
            _priceControllers[p.storeId] = TextEditingController(
              text: p.price?.toString() ?? '',
            );
          }
        }
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _nameEn.dispose();
    _nameAr.dispose();
    _brand.dispose();
    _barcode.dispose();
    _note.dispose();
    _imageUrl.dispose();
    for (final c in _priceControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final currency = ref.watch(currencyProvider);

    if (_loading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_existing == null ? l.addItem : l.editItem),
        actions: [
          IconButton(
            tooltip: l.lookupMethod,
            icon: _lookingUp
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.travel_explore),
            onPressed: _lookingUp ? null : _lookupOnline,
          ),
          IconButton(
            tooltip: l.scanBarcode,
            icon: const Icon(Icons.qr_code_scanner_rounded),
            onPressed: () async {
              final code = await context.push<String>(Routes.scan());
              if (code != null && code.isNotEmpty) {
                setState(() => _barcode.text = code);
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: l.generalTab),
            Tab(text: l.pricesTab),
            Tab(text: l.historyTab),
          ],
        ),
      ),
      body: Form(
        key: _formKey,
        child: TabBarView(
          controller: _tabs,
          children: [
            _GeneralTab(state: this, onChanged: () => setState(() {})),
            _PricesTab(
              state: this,
              currency: currency,
              onChanged: () => setState(() {}),
            ),
            _HistoryTab(itemId: _existing?.id),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.space4,
            AppDimens.space2,
            AppDimens.space4,
            AppDimens.space3,
          ),
          child: FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(AppDimens.minTouchTarget),
            ),
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l.commonSave),
          ),
        ),
      ),
    );
  }

  // ── Lookup ──────────────────────────────────────────────────────────────
  Future<void> _lookupOnline() async {
    final l = AppLocalizations.of(context)!;
    final barcode = _barcode.text.trim();
    if (barcode.isEmpty) {
      _tabs.animateTo(0);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.barcodeField)));
      return;
    }

    final source = await showDialog<LookupSource>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l.lookupMethod),
        children: [
          for (final s in LookupSource.values)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(s),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(switch (s) {
                  LookupSource.auto => l.sourceAuto,
                  LookupSource.openFoodFacts => l.sourceOpenFoodFacts,
                  LookupSource.searxng => l.sourceSearxng,
                }),
              ),
            ),
        ],
      ),
    );
    if (source == null || !mounted) return;

    setState(() => _lookingUp = true);
    try {
      final product = await ref
          .read(barcodeServiceProvider)
          .lookupFromSource(barcode, source, skipLocal: true)
          .then((lookup) => lookup.onlineProduct);
      if (!mounted) return;
      if (product != null) {
        setState(() {
          if (_nameEn.text.trim().isEmpty) _nameEn.text = product.name;
          if (product.nameAr != null && _nameAr.text.trim().isEmpty) {
            _nameAr.text = product.nameAr!;
          }
          if (product.brand != null && _brand.text.trim().isEmpty) {
            _brand.text = product.brand!;
          }
          if (product.imageUrl != null && _imageUrl.text.trim().isEmpty) {
            _imageUrl.text = product.imageUrl!;
          }
          if (product.price != null) {
            ref.read(databaseProvider).storeDao.getOrCreateDefault().then((
              store,
            ) {
              if (!mounted) return;
              setState(() {
                _activeStores.add(store.id);
                final existing = _priceControllers[store.id];
                if (existing == null || existing.text.trim().isEmpty) {
                  (_priceControllers[store.id] ??= TextEditingController())
                      .text = product.price!
                      .toString();
                }
              });
            });
          }
        });
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.scanResultNotFound)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.errorLookupFailed)));
      }
    } finally {
      if (mounted) setState(() => _lookingUp = false);
    }
  }

  // ── Save ────────────────────────────────────────────────────────────────
  Future<void> _save() async {
    final l = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) {
      _tabs.animateTo(0);
      return;
    }
    setState(() => _saving = true);
    try {
      final db = ref.read(databaseProvider);
      final displayCurrency = ref.read(currencyProvider);
      final now = DateTime.now().toIso8601String();

      final companion = ItemsCompanion.insert(
        nameEn: _nameEn.text.trim(),
        createdAt: _existing?.createdAt ?? now,
        updatedAt: now,
        barcode: Value(
          _barcode.text.trim().isEmpty ? null : _barcode.text.trim(),
        ),
        brand: Value(_brand.text.trim().isEmpty ? null : _brand.text.trim()),
        // FIX vs v1: the Arabic name is now persisted.
        nameAr: Value(_nameAr.text.trim().isEmpty ? null : _nameAr.text.trim()),
        note: Value(_note.text.trim().isEmpty ? null : _note.text.trim()),
        imageUrl: Value(
          _imageUrl.text.trim().isNotEmpty
              ? _imageUrl.text.trim()
              : _localImagePath,
        ),
        categoryId: Value(_categoryId),
        currency: Value(displayCurrency.code),
      );

      final id = _existing == null
          ? await db.itemDao.insertItem(companion)
          : await db.itemDao.upsertByBarcode(companion);

      // Per-store prices: remove unselected, upsert selected.
      final existingLinks = await db.itemStoreDao.forItem(id);
      for (final link in existingLinks) {
        if (!_activeStores.contains(link.storeId)) {
          await db.itemStoreDao.removeByItemAndStore(id, link.storeId);
        }
      }
      for (final storeId in _activeStores) {
        final priceText = _priceControllers[storeId]?.text.trim() ?? '';
        final price = double.tryParse(priceText.replaceAll(',', '.'));
        await db.itemStoreDao.upsertWithHistory(
          ItemStoresCompanion.insert(
            itemId: id,
            storeId: storeId,
            price: Value(price),
            currency: Value(displayCurrency.code),
          ),
        );
      }
      if (_activeStores.isEmpty) {
        await ref.read(barcodeServiceProvider).ensureDefaultStoreLink(id);
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.itemSaved)));
        context.pop();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.saveFailed)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickImage() async {
    final xfile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
    );
    if (xfile != null) {
      setState(() => _localImagePath = xfile.path);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// General tab
// ═══════════════════════════════════════════════════════════════════════════
class _GeneralTab extends ConsumerWidget {
  final _AddEditItemScreenState state;
  final VoidCallback onChanged;

  const _GeneralTab({required this.state, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final categories = ref.watch(categoriesStreamProvider).value ?? const [];
    final s = state;

    return ListView(
      padding: AppDimens.pagePadding.copyWith(bottom: 24),
      children: [
        Center(
          child: Stack(
            children: [
              AppImage(
                url: s._imageUrl.text.isNotEmpty
                    ? s._imageUrl.text
                    : s._localImagePath,
                size: 120,
              ),
              Positioned.directional(
                textDirection: Directionality.of(context),
                end: -8,
                bottom: -8,
                child: IconButton.filledTonal(
                  onPressed: s._pickImage,
                  icon: const Icon(Icons.photo_camera_outlined, size: 18),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimens.space4),
        TextFormField(
          controller: s._nameEn,
          textInputAction: TextInputAction.next,
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? l.nameRequired : null,
          decoration: InputDecoration(labelText: l.nameEnField),
        ),
        const SizedBox(height: AppDimens.space3),
        TextFormField(
          controller: s._nameAr,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(labelText: l.nameArField),
        ),
        const SizedBox(height: AppDimens.space3),
        TextFormField(
          controller: s._brand,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(labelText: l.brandField),
        ),
        const SizedBox(height: AppDimens.space3),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: s._barcode,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontFamily: 'AppMono',
                ),
                decoration: InputDecoration(labelText: l.barcodeField),
              ),
            ),
            const SizedBox(width: AppDimens.space2),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: IconButton.filledTonal(
                tooltip: l.scanBarcode,
                onPressed: () async {
                  final code = await context.push<String>(Routes.scan());
                  if (code != null && code.isNotEmpty) {
                    s._barcode.text = code;
                    onChanged();
                  }
                },
                icon: const Icon(Icons.qr_code_scanner_rounded),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimens.space3),
        DropdownButtonFormField<int?>(
          initialValue: s._categoryId,
          decoration: InputDecoration(labelText: l.categoryField),
          items: [
            DropdownMenuItem<int?>(value: null, child: Text(l.commonNone)),
            for (final c in categories)
              DropdownMenuItem<int?>(
                value: c.id,
                child: Text(
                  c.displayName(
                    ref.read(localeProvider.notifier).effectiveCode,
                  ),
                ),
              ),
          ],
          onChanged: (v) {
            s._categoryId = v;
            onChanged();
          },
        ),
        const SizedBox(height: AppDimens.space3),
        TextFormField(
          controller: s._note,
          maxLines: 3,
          decoration: InputDecoration(labelText: l.noteField),
        ),
        const SizedBox(height: AppDimens.space3),
        TextFormField(
          controller: s._imageUrl,
          decoration: InputDecoration(labelText: l.imageUrlField),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Prices tab
// ═══════════════════════════════════════════════════════════════════════════
class _PricesTab extends ConsumerWidget {
  final _AddEditItemScreenState state;
  final AppCurrency currency;
  final VoidCallback onChanged;

  const _PricesTab({
    required this.state,
    required this.currency,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final stores = ref.watch(storesStreamProvider).value ?? const [];
    final s = state;

    return ListView(
      padding: AppDimens.pagePadding.copyWith(bottom: 24),
      children: [
        SectionHeader(l.priceAtStores, padding: EdgeInsets.zero),
        if (stores.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppDimens.space6),
            child: Center(child: Text(l.noStoresForPrice)),
          )
        else
          for (final store in stores)
            Padding(
              padding: const EdgeInsets.only(bottom: AppDimens.space2),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      Checkbox(
                        value: s._activeStores.contains(store.id),
                        onChanged: (checked) {
                          if (checked == true) {
                            s._activeStores.add(store.id);
                            s._priceControllers.putIfAbsent(
                              store.id,
                              () => TextEditingController(),
                            );
                          } else {
                            s._activeStores.remove(store.id);
                          }
                          onChanged();
                        },
                      ),
                      Expanded(
                        child: Text(
                          store.displayName(
                            ref.read(localeProvider.notifier).effectiveCode,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (s._activeStores.contains(store.id))
                        SizedBox(
                          width: 110,
                          child: TextFormField(
                            controller: s._priceControllers[store.id],
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: l.priceInputHint,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// History tab
// ═══════════════════════════════════════════════════════════════════════════
class _HistoryTab extends ConsumerWidget {
  final int? itemId;

  const _HistoryTab({required this.itemId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final currency = ref.watch(currencyProvider);
    final locale = ref.watch(
      localeProvider.select((s) => s?.languageCode ?? 'en'),
    );

    if (itemId == null) {
      return Center(child: Text(l.noPriceHistory));
    }
    final history = ref.watch(_historyFamily(itemId!));

    return history.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (rows) {
        if (rows.isEmpty) {
          return Center(child: Text(l.noPriceHistory));
        }
        return ListView.builder(
          padding: AppDimens.pagePadding,
          itemCount: rows.length,
          itemBuilder: (context, i) {
            final r = rows[i];
            return ListTile(
              leading: Icon(
                Icons.history_rounded,
                color: theme.colorScheme.primary,
              ),
              title: Text(r.store.displayName(locale)),
              subtitle: Text(r.history.recordedAt),
              trailing: PriceText(
                r.history.price != null
                    ? currencyFromCode(
                        r.history.currency,
                      ).convertTo(r.history.price!, currency)
                    : null,
                currency: currency,
              ),
            );
          },
        );
      },
    );
  }
}

final _historyFamily = StreamProvider.family<List<PriceHistoryWithStore>, int>((
  ref,
  itemId,
) {
  return ref.watch(databaseProvider).itemDao.watchPriceHistory(itemId);
});
