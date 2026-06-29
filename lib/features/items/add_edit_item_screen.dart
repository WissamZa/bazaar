import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/database/dao/item_dao.dart';
import '../../core/database/dao/store_dao.dart';
import '../../core/database/dao/category_dao.dart';
import '../../core/models/item.dart';
import '../../core/models/category.dart';
import '../../core/models/store.dart';
import '../../core/constants/currencies.dart';
import '../../core/providers/locale_provider.dart';
import '../../core/services/barcode_service.dart';
import '../../core/services/scraper_service.dart';
import '../scanner/scanner_screen.dart';
import '../scanner/scan_result_screen.dart';

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
  late final TextEditingController _price;
  late AppCurrency _currency;
  Store? _selectedStore;
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
            context.read<LocaleProvider>().locale?.languageCode ?? 'en',),);
    _barcode = TextEditingController(text: i?.barcode ?? '');
    _price = TextEditingController(
      text: i?.price == null ? '' : i!.price!.toStringAsFixed(2),
    );
    _currency = i?.currency ?? AppCurrency.sar;
    _selectedCategory =
        i?.categoryId != null ? null : null; // Need to load first
    _imageUrl = i?.imageUrl;
    _loadStores();
    _loadCategories();
  }

  @override
  void dispose() {
    _name.dispose();
    _barcode.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _loadStores() async {
    _stores = await StoreDao.instance.all();
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

    // Let the user choose which source to query (default: Auto).
    final locale = context.read<LocaleProvider>();
    final langCode = locale.locale?.languageCode ?? 'en';
    final LookupSource? picked = await showDialog<LookupSource>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(locale.isRtl ? 'البحث في:' : 'Look up in:'),
        children: LookupSource.values
            .map(
              (s) => SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, s),
                child: Row(
                  children: [
                    const Icon(Icons.travel_explore_outlined, size: 20),
                    const SizedBox(width: 12),
                    Text(s.displayName(langCode)),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
    if (picked == null) return;

    setState(() => _busy = true);
    final lookup = picked == LookupSource.auto
        ? await BarcodeService.instance.lookup(code)
        : await BarcodeService.instance.lookupFromSource(code, picked);
    setState(() => _busy = false);

    if (!lookup.found) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(locale.isRtl
                ? 'فشل البحث عن الباركود'
                : 'Barcode lookup failed',),),
      );
      return;
    }

    if (lookup.foundLocal) {
      final item = lookup.localItem!;
      setState(() {
        _name.text = item.displayName(langCode);
        _price.text = item.price?.toStringAsFixed(2) ?? '';
        _currency = item.currency;
        _imageUrl = item.imageUrl;
        _selectedCategory = null; // We'd need to load it if we want
      });
    } else if (lookup.foundOnline) {
      final product = lookup.onlineProduct!;
      setState(() {
        _name.text = product.name;
        _price.text = product.price?.toStringAsFixed(2) ?? '';
        _currency = CurrencyExtension.fromCode(product.currency);
        _imageUrl = product.imageUrl;
      });
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            locale.isRtl
                ? 'لم يتم العثور على المنتج في ${picked.displayName('ar')}'
                : 'Not found in ${picked.displayName('en')}',
          ),
          action: SnackBarAction(
            label: locale.isRtl ? 'مصادر أخرى' : 'Other sources',
            onPressed: _lookupBarcode,
          ),
        ),
      );
    }
  }

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
            context.read<LocaleProvider>().isRtl ? 'رابط الصورة' : 'Image URL',),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'https://...'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                  context.read<LocaleProvider>().isRtl ? 'إلغاء' : 'Cancel',),),
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
        title: Text(context.read<LocaleProvider>().isRtl
            ? 'إضافة تصنيف'
            : 'Add Category',),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              decoration: InputDecoration(
                  labelText: context.read<LocaleProvider>().isRtl
                      ? 'الاسم (إنجليزي)'
                      : 'Name (English)',),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: arCtrl,
              decoration: InputDecoration(
                  labelText: context.read<LocaleProvider>().isRtl
                      ? 'الاسم (عربي)'
                      : 'Name (Arabic)',),
              textDirection: TextDirection.rtl,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                  context.read<LocaleProvider>().isRtl ? 'إلغاء' : 'Cancel',),),
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
        ),),
      );
      return;
    }
    setState(() => _busy = true);
    final now = DateTime.now();
    final existing = widget.item;
    final price = double.tryParse(_price.text.trim());
    final item = Item(
      id: existing?.id,
      barcode: _barcode.text.trim().isEmpty ? null : _barcode.text.trim(),
      nameEn: name,
      nameAr: null,
      price: price,
      currency: _currency,
      imageUrl: _imageUrl,
      categoryId: _selectedCategory?.id,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    if (existing == null) {
      await ItemDao.instance.insert(item);
    } else {
      await ItemDao.instance.update(item);
    }
    if (!mounted) return;
    setState(() => _busy = false);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final isRtl = locale.isRtl;
    return Scaffold(
      appBar: AppBar(
        title: Text(isRtl
            ? (widget.item == null ? 'إضافة منتج' : 'تعديل المنتج')
            : (widget.item == null ? 'Add Item' : 'Edit Item'),),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
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
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _price,
                      decoration: InputDecoration(
                        labelText: isRtl ? 'السعر' : 'Price',
                        prefixIcon: const Icon(Icons.attach_money),
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<AppCurrency>(
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
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<Category?>(
                      initialValue: _selectedCategory,
                      decoration: InputDecoration(
                        labelText: isRtl ? 'التصنيف' : 'Category',
                        prefixIcon: const Icon(Icons.category_outlined),
                      ),
                      items: [
                        DropdownMenuItem<Category?>(
                          value: null,
                          child: Text(isRtl ? '— لا يوجد —' : '— None —'),
                        ),
                        ..._categories.map(
                          (c) => DropdownMenuItem<Category?>(
                            value: c,
                            child: Text(c.displayName(
                                locale.locale?.languageCode ?? 'en',),),
                          ),
                        ),
                      ],
                      onChanged: (v) => setState(() => _selectedCategory = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: _addNewCategory,
                    icon: const Icon(Icons.add),
                    tooltip: isRtl ? 'إضافة تصنيف' : 'Add Category',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<Store?>(
                initialValue: _selectedStore,
                decoration: InputDecoration(
                  labelText: isRtl ? 'المتجر' : 'Store',
                  prefixIcon: const Icon(Icons.storefront_outlined),
                ),
                items: [
                  DropdownMenuItem<Store?>(
                    value: null,
                    child: Text(isRtl ? '— لا أحد —' : '— None —'),
                  ),
                  ..._stores.map(
                    (s) => DropdownMenuItem<Store?>(
                      value: s,
                      child: Text(
                          s.displayName(locale.locale?.languageCode ?? 'en'),),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => _selectedStore = v),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: _pickImage,
                      icon: Icon(
                          _imageUrl == null ? Icons.image : Icons.check_circle,),
                      label: Text(_imageUrl == null
                          ? (isRtl ? 'إضافة صورة' : 'Add Image')
                          : (isRtl ? 'تغيير الصورة' : 'Change Image'),),
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
              const SizedBox(height: 24),
              FilledButton.icon(
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
            ],
          ),
        ),
      ),
    );
  }
}
