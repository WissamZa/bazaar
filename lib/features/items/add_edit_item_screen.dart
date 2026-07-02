import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/database/dao/item_dao.dart';
import '../../core/database/dao/store_dao.dart';
import '../../core/database/dao/category_dao.dart';
import '../../core/database/dao/item_store_dao.dart';
import '../../core/models/item.dart';
import '../../core/models/category.dart';
import '../../core/models/store.dart';
import '../../core/models/item_store.dart';
import '../../core/constants/currencies.dart';
import '../../core/providers/locale_provider.dart';
import '../../core/providers/scraping_provider.dart';
import '../../core/services/barcode_service.dart';
import '../../core/services/scraper_service.dart';
import '../scanner/scanner_screen.dart';
import '../scanner/scan_result_screen.dart';
import 'widgets/category_selector.dart';
import 'widgets/store_price_selector.dart';
import 'widgets/price_history_list.dart';

/// Add or edit an [Item]. When [item] is null we are creating a new one.
class AddEditItemScreen extends StatefulWidget {
  final Item? item;
  const AddEditItemScreen({super.key, this.item});

  @override
  State<AddEditItemScreen> createState() => _AddEditItemScreenState();
}

class _AddEditItemScreenState extends State<AddEditItemScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _barcode;
  late final TextEditingController _brand;
  late final TextEditingController _note;
  final Map<int, TextEditingController> _storePriceControllers = {};
  late AppCurrency _currency;
  Set<Store> _selectedStores = {};
  List<Store> _stores = [];
  Category? _selectedCategory;
  List<Category> _categories = [];
  String? _imageUrl;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final i = widget.item;
    _name = TextEditingController(
      text: i?.displayName(
        context.read<LocaleProvider>().locale?.languageCode ?? 'en',
      ),
    );
    _barcode = TextEditingController(text: i?.barcode ?? '');
    _brand = TextEditingController(text: i?.brand ?? '');
    _note = TextEditingController(text: i?.note ?? '');
    _currency = i?.currency ?? AppCurrency.sar;
    _imageUrl = i?.imageUrl;
    _loadStores();
    _loadCategories();
  }

  @override
  void dispose() {
    _name.dispose();
    _barcode.dispose();
    _brand.dispose();
    _note.dispose();
    for (var c in _storePriceControllers.values) {
      c.dispose();
    }
  }

  Future<void> _loadStores() async {
    _stores = await StoreDao.instance.all();
    _selectedStores = {};
    _storePriceControllers.clear();

    if (widget.item != null && widget.item!.id != null) {
      final relations = await ItemStoreDao.instance.forItem(widget.item!.id!);
      final ids = relations.map((r) => r.storeId).toSet();
      _selectedStores = _stores.where((s) => ids.contains(s.id)).toSet();

      for (final rel in relations) {
        _storePriceControllers[rel.storeId] = TextEditingController(
          text: rel.price?.toStringAsFixed(2) ?? '',
        );
      }
    }
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _loadCategories() async {
    _categories = await CategoryDao.instance.all();
    if (widget.item != null && widget.item!.categoryId != null) {
      _selectedCategory =
          await CategoryDao.instance.findById(widget.item!.categoryId!);
    }
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _lookupBarcode() async {
    final code = _barcode.text.trim();
    if (code.isEmpty) return;

    final locale = context.read<LocaleProvider>();
    final langCode = locale.locale?.languageCode ?? 'en';
    final scraping = context.read<ScrapingProvider>();

    // New: show a STRATEGY picker, not the old source picker.
    // Strategies run the full Tier 1 + 2 + 3 pipeline.
    // "Basic SearXNG (multi-result picker)" preserves the old behavior.
    final _LookupChoice? picked = await showDialog<_LookupChoice>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(locale.isRtl ? 'طريقة البحث:' : 'Lookup method:'),
        children: [
          // ── Default: use the strategy currently set in Settings ──
          SimpleDialogOption(
            onPressed: () => Navigator.pop(
                ctx, _LookupChoice.useConfigured()),
            child: _ChoiceRow(
              icon: Icons.auto_awesome,
              iconColor: Theme.of(ctx).colorScheme.primary,
              title: locale.isRtl
                  ? 'استخدم الإعداد الحالي'
                  : 'Use current setting',
              subtitle: scraping.strategy.displayName(langCode),
            ),
          ),
          const Divider(height: 1),
          // ── Each strategy as an explicit option ──
          for (final strat in ExtractionStrategy.values)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(
                  ctx, _LookupChoice.strategy(strat)),
              child: _ChoiceRow(
                icon: _iconForStrategy(strat),
                title: strat.displayName(langCode),
                subtitle: _subtitleForStrategy(strat, langCode),
              ),
            ),
          const Divider(height: 1),
          // ── Legacy: basic SearXNG multi-result picker ──
          SimpleDialogOption(
            onPressed: () =>
                Navigator.pop(ctx, _LookupChoice.basicSearxng()),
            child: _ChoiceRow(
              icon: Icons.list_alt,
              iconColor: Theme.of(ctx).colorScheme.tertiary,
              title: locale.isRtl
                  ? 'SearXNG أساسي (قائمة نتائج)'
                  : 'Basic SearXNG (result list)',
              subtitle: locale.isRtl
                  ? 'يفتح نافذة لاختيار المنتج من نتائج SearXNG الخام'
                  : 'Opens a picker to choose from raw SearXNG results',
            ),
          ),
        ],
      ),
    );
    if (picked == null) return;

    setState(() => _busy = true);

    try {
      // ── Branch 1: Basic SearXNG multi-result picker (legacy) ──────
      if (picked.isBasicSearxng) {
        await _runBasicSearxngPicker(code, locale, langCode);
        return;
      }

      // ── Branch 2: Run the new pipeline with the picked strategy ──
      final strategy =
          picked.strategy ?? scraping.strategy;
      final product = await ScraperService.instance
          .searchBarcodeWithStrategy(code, strategy);

      setState(() => _busy = false);

      if (product == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(locale.isRtl
                ? 'لم يتم العثور على المنتج'
                : 'Product not found'),
            action: SnackBarAction(
              label: locale.isRtl ? 'طريقة أخرى' : 'Other method',
              onPressed: _lookupBarcode,
            ),
          ),
        );
        return;
      }

      // Fill in the form with the extracted data.
      setState(() {
        _name.text = product.name;
        _currency = CurrencyExtension.fromCode(product.currency);
        _imageUrl = product.imageUrl;
        // brand is now available — would need a _brand field; left as TODO
        // since the existing form doesn't have one wired.
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            locale.isRtl
                ? 'تم العثور على المنتج عبر: ${product.source}'
                : 'Found via: ${product.source}'
            '${product.price != null ? " · ${product.currency} ${product.price}" : ""}',
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lookup error: $e')),
      );
    }
  }

  /// Legacy basic SearXNG flow — opens a multi-result picker dialog.
  Future<void> _runBasicSearxngPicker(
    String code,
    LocaleProvider locale,
    String langCode,
  ) async {
    final results =
        await ScraperService.instance.searchBarcodeSearXNGMulti(code);
    setState(() => _busy = false);

    if (results.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(locale.isRtl
              ? 'لم يتم العثور على نتائج في سيركس إن جي'
              : 'No results found in SearXNG'),
        ),
      );
      return;
    }

    final ScrapedProduct? pickedProduct = await showDialog<ScrapedProduct>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(locale.isRtl
            ? 'اختر المنتج الصحيح'
            : 'Pick the right product'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: results.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (ctx, i) {
              final p = results[i];
              return ListTile(
                leading: p.imageUrl != null
                    ? Image.network(p.imageUrl!,
                        width: 40, height: 40, fit: BoxFit.cover)
                    : const Icon(Icons.image),
                title: Text(p.name),
                onTap: () => Navigator.pop(ctx, p),
              );
            },
          ),
        ),
      ),
    );

    if (pickedProduct != null) {
      setState(() {
        _name.text = pickedProduct.name;
        _currency = CurrencyExtension.fromCode(pickedProduct.currency);
        _imageUrl = pickedProduct.imageUrl;
      });
    }
  }

  static IconData _iconForStrategy(ExtractionStrategy s) => switch (s) {
        ExtractionStrategy.schemaOnly => Icons.code,
        ExtractionStrategy.schemaThenCloudLlm => Icons.cloud_upload_outlined,
        ExtractionStrategy.schemaThenOnDevice => Icons.phone_android,
        ExtractionStrategy.schemaCloudOnDevice => Icons.all_inclusive,
        ExtractionStrategy.cloudLlmOnly => Icons.cloud,
        ExtractionStrategy.onDeviceOnly => Icons.memory,
      };

  static String _subtitleForStrategy(
          ExtractionStrategy s, String langCode) =>
      switch (s) {
        ExtractionStrategy.schemaOnly => langCode == 'ar'
            ? 'يحلل JSON-LD فقط — مجاني وسريع'
            : 'Parses JSON-LD only — free & fast',
        ExtractionStrategy.schemaThenCloudLlm => langCode == 'ar'
            ? 'بنية → سحابة LLM كاحتياطي'
            : 'Schema → Cloud LLM as fallback',
        ExtractionStrategy.schemaThenOnDevice => langCode == 'ar'
            ? 'بنية → LLM محلي كاحتياطي (يعمل بدون إنترنت)'
            : 'Schema → On-device LLM as fallback (offline)',
        ExtractionStrategy.schemaCloudOnDevice => langCode == 'ar'
            ? 'الكل بالترتيب: بنية ← سحابة ← محلي'
            : 'All in order: Schema → Cloud → On-device',
        ExtractionStrategy.cloudLlmOnly => langCode == 'ar'
            ? 'سحابة LLM مباشرة (تخطي البنية)'
            : 'Cloud LLM directly (skip schema)',
        ExtractionStrategy.onDeviceOnly => langCode == 'ar'
            ? 'LLM محلي مباشرة (تخطي البنية)'
            : 'On-device LLM directly (skip schema)',
      };

  Future<void> _openScanner() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const ScannerScreen()),
    );
    if (code == null) return;
    if (!mounted) return;
    // If user accepts a result, refresh fields with whatever they saved.
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ScanResultScreen(code: code)),
    );
    if (saved == true && mounted) {
      Navigator.of(context).pop();
    } else {
      _barcode.text = code;
      setState(() {});
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;
    setState(() {
      _imageUrl = image.path;
    });
  }

  Future<void> _pickImageUrl() async {
    final ctrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          context.read<LocaleProvider>().isRtl ? 'رابط الصورة' : 'Image URL',
        ),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'https://...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              context.read<LocaleProvider>().isRtl ? 'إلغاء' : 'Cancel',
            ),
          ),
          FilledButton(
            onPressed: () {
              setState(() {
                _imageUrl = ctrl.text.trim();
              });
              Navigator.pop(ctx);
            },
            child: Text(context.read<LocaleProvider>().isRtl ? 'حفظ' : 'Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _addNewCategory() async {
    final ctrl = TextEditingController();
    final arCtrl = TextEditingController();
    String? newCatName;
    String? newCatAr;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          context.read<LocaleProvider>().isRtl ? 'إضافة تصنيف' : 'Add Category',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              decoration: InputDecoration(
                labelText: context.read<LocaleProvider>().isRtl
                    ? 'الاسم (إنجليزي)'
                    : 'Name (English)',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: arCtrl,
              decoration: InputDecoration(
                labelText: context.read<LocaleProvider>().isRtl
                    ? 'الاسم (عربي)'
                    : 'Name (Arabic)',
              ),
              textDirection: TextDirection.rtl,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              context.read<LocaleProvider>().isRtl ? 'إلغاء' : 'Cancel',
            ),
          ),
          FilledButton(
            onPressed: () {
              newCatName = ctrl.text.trim();
              newCatAr = arCtrl.text.trim();
              Navigator.pop(ctx);
            },
            child: Text(context.read<LocaleProvider>().isRtl ? 'حفظ' : 'Save'),
          ),
        ],
      ),
    );

    if (newCatName == null || newCatName!.trim().isEmpty) return;

    final cat = Category(
      name: newCatName!,
      nameAr: newCatAr,
      createdAt: DateTime.now(),
    );
    await CategoryDao.instance.insert(cat);
    await _loadCategories();
    setState(() {
      _selectedCategory = _categories.last;
    });
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<LocaleProvider>().isRtl
                ? 'أدخل اسم المنتج'
                : 'Enter product name',
          ),
        ),
      );
      return;
    }
    setState(() => _busy = true);
    final now = DateTime.now();
    final existing = widget.item;

    // 1. Determine if we should update an existing item based on barcode
    int? itemId = existing?.id;
    final barcode = _barcode.text.trim();
    if (itemId == null && barcode.isNotEmpty) {
      final found = await ItemDao.instance.findByBarcode(barcode);
      if (found != null) {
        itemId = found.id;
      }
    }

    final item = Item(
      id: itemId,
      barcode: barcode.isEmpty ? null : barcode,
      brand: _brand.text.trim().isEmpty ? null : _brand.text.trim(),
      nameEn: name,
      nameAr: null,
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      price: null, // Prices are now store-specific
      currency: _currency,
      imageUrl: _imageUrl,
      categoryId: _selectedCategory?.id,
      createdAt: (itemId != null)
          ? (existing?.createdAt ??
              (await ItemDao.instance.findById(itemId) ??
                      Item(
                        nameEn: name,
                        createdAt: now,
                        updatedAt: now,
                      ))
                  .createdAt)
          : now,
      updatedAt: now,
    );

    if (itemId == null) {
      itemId = await ItemDao.instance.insert(item);
    } else {
      await ItemDao.instance.update(item);
    }

    // 2. Update store relationships
    await ItemStoreDao.instance.deleteByItemId(itemId);
    for (final store in _selectedStores) {
      final priceText = _storePriceControllers[store.id]?.text.trim() ?? '';
      final price = double.tryParse(priceText);

      await ItemStoreDao.instance.upsert(
        ItemStore(
          itemId: itemId,
          storeId: store.id!,
          price: price,
          currency: _currency,
        ),
      );
    }

    // 3. If no stores were selected, link to the Default store so the item
    //    is never orphaned. (User can always remove it from there later.)
    if (_selectedStores.isEmpty && itemId != null) {
      final savedItem = item.copyWith(id: itemId, updatedAt: now);
      await BarcodeService.instance.ensureDefaultStoreLink(savedItem);
    }

    if (!mounted) return;
    setState(() => _busy = false);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final isRtl = locale.isRtl;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            isRtl
                ? (widget.item == null ? 'إضافة منتج' : 'تعديل المنتج')
                : (widget.item == null ? 'Add Item' : 'Edit Item'),
          ),
          bottom: TabBar(
            tabs: [
              Tab(text: isRtl ? 'عام' : 'General'),
              Tab(text: isRtl ? 'الأسعار' : 'Prices'),
              Tab(text: isRtl ? 'تاريخ الأسعار' : 'History'),
            ],
          ),
        ),
        body: Form(
          key: _formKey,
          child: TabBarView(
            children: [
              _buildGeneralTab(context, isRtl),
              _buildPricesTab(context, isRtl),
              _buildHistoryTab(context, isRtl),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              onPressed: _busy ? null : _save,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(isRtl ? 'حفظ' : 'Save'),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGeneralTab(BuildContext context, bool isRtl) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _name,
            decoration: InputDecoration(
              labelText: isRtl ? 'اسم المنتج' : 'Product Name',
              prefixIcon: const Icon(Icons.label_outline),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _brand,
            decoration: InputDecoration(
              labelText: isRtl ? 'الماركة' : 'Brand',
              prefixIcon: const Icon(Icons.branding_watermark),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _barcode,
                  decoration: InputDecoration(
                    labelText: isRtl ? 'الباركود' : 'Barcode',
                    prefixIcon: const Icon(Icons.qr_code),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: _openScanner,
                icon: const Icon(Icons.qr_code_scanner),
                tooltip: isRtl ? 'مسح الباركود' : 'Scan Barcode',
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: _lookupBarcode,
                icon: const Icon(Icons.search),
                tooltip: isRtl ? 'بحث عن باركود' : 'Lookup Barcode',
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _note,
            decoration: InputDecoration(
              labelText: isRtl ? 'ملاحظات' : 'Notes',
              prefixIcon: const Icon(Icons.note_alt_outlined),
            ),
            maxLines: 3,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButton<AppCurrency>(
                  value: _currency,
                  items: const [
                    DropdownMenuItem(
                      value: AppCurrency.sar,
                      child: Text('SAR ﷼'),
                    ),
                    DropdownMenuItem(
                      value: AppCurrency.usd,
                      child: Text('USD \$'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _currency = v);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: _pickImage,
                  icon: Icon(
                    _imageUrl == null ? Icons.image : Icons.check_circle,
                  ),
                  label: Text(
                    _imageUrl == null
                        ? (isRtl ? 'إضافة صورة' : 'Add Image')
                        : (isRtl ? 'تغيير الصورة' : 'Change Image'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: _pickImageUrl,
                icon: const Icon(Icons.link),
                label: Text(isRtl ? 'رابط' : 'URL'),
              ),
              if (_imageUrl != null)
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _imageUrl = null),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPricesTab(BuildContext context, bool isRtl) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StorePriceSelector(
            selectedStores: _selectedStores,
            allStores: _stores,
            priceControllers: _storePriceControllers,
            onStoreToggled: (Store store) {
              setState(() {
                if (_selectedStores.contains(store)) {
                  _selectedStores.remove(store);
                  _storePriceControllers.remove(store.id);
                  _storePriceControllers[store.id]?.dispose();
                } else {
                  _selectedStores.add(store);
                  _storePriceControllers.putIfAbsent(
                    store.id!,
                    () => TextEditingController(),
                  );
                }
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab(BuildContext context, bool isRtl) {
    if (widget.item == null || widget.item!.id == null) {
      return Center(
        child: Text(isRtl
            ? 'يجب حفظ المنتج أولاً لرؤية التاريخ'
            : 'Must save item first to see history'),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: PriceHistoryList(itemId: widget.item!.id!),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
// Helpers for the new strategy-picker lookup dialog
// ───────────────────────────────────────────────────────────────────────────

/// User's choice in the lookup-method dialog.
class _LookupChoice {
  /// If non-null, run this specific strategy for the lookup.
  /// If null, use the strategy currently configured in ScrapingProvider.
  final ExtractionStrategy? strategy;

  /// If true, run the legacy `searchBarcodeSearXNGMulti` flow that opens a
  /// multi-result picker.
  final bool isBasicSearxng;

  const _LookupChoice._({this.strategy, this.isBasicSearxng = false});

  factory _LookupChoice.useConfigured() => const _LookupChoice._();
  factory _LookupChoice.strategy(ExtractionStrategy s) =>
      _LookupChoice._(strategy: s);
  factory _LookupChoice.basicSearxng() =>
      const _LookupChoice._(isBasicSearxng: true);
}

/// Two-line row used in the lookup-method SimpleDialog.
class _ChoiceRow extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  const _ChoiceRow({
    required this.icon,
    this.iconColor,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 22, color: iconColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(fontWeight: FontWeight.w500)),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

