import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/currencies.dart';
import '../../core/database/dao/item_dao.dart';
import '../../core/models/item.dart';
import '../../core/providers/locale_provider.dart';
import '../../core/services/barcode_service.dart';
import '../../core/services/scraper_service.dart';
import '../items/add_edit_item_screen.dart';

/// Result of a barcode scan. Looks up local DB first, falls back to online
/// scraping, and offers the user a way to save a new item or open an existing
/// one. The user can choose which online source to query (Open Food Facts,
/// Amazon SA, Noon, Panda, Carrefour SA) or run the full "Auto" chain.
class ScanResultScreen extends StatefulWidget {
  final String code;
  const ScanResultScreen({super.key, required this.code});

  @override
  State<ScanResultScreen> createState() => _ScanResultScreenState();
}

class _ScanResultScreenState extends State<ScanResultScreen> {
  bool _loading = true;
  BarcodeLookup? _lookup;
  LookupSource _source = LookupSource.auto;

  @override
  void initState() {
    super.initState();
    _doLookup();
  }

  Future<void> _doLookup() async {
    setState(() => _loading = true);
    final lookup = _source == LookupSource.auto
        ? await BarcodeService.instance.lookup(widget.code)
        : await BarcodeService.instance.lookupFromSource(
            widget.code,
            _source,
          );
    if (!mounted) return;
    setState(() {
      _lookup = lookup;
      _loading = false;
    });
  }

  Future<void> _changeSource(LookupSource newSource) async {
    if (newSource == _source) return;
    setState(() => _source = newSource);
    await _doLookup();
  }

  Future<void> _saveOnlineAsItem() async {
    final product = _lookup?.onlineProduct;
    if (product == null) return;
    final item = Item(
      barcode: widget.code,
      nameEn: product.name,
      nameAr: product.nameAr,
      price: product.price,
      currency: CurrencyExtension.fromCode(product.currency),
      imageUrl: product.imageUrl,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await ItemDao.instance.upsertByBarcode(item);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _openManualForm() async {
    final product = _lookup?.onlineProduct;
    final prefill = Item(
      barcode: widget.code,
      nameEn: product?.name ?? '',
      nameAr: product?.nameAr,
      price: product?.price,
      currency: CurrencyExtension.fromCode(product?.currency ?? 'SAR'),
      imageUrl: product?.imageUrl,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AddEditItemScreen(item: prefill)),
    );
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _openExistingItem() async {
    final item = _lookup?.localItem;
    if (item == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AddEditItemScreen(item: item)),
    );
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final isRtl = locale.isRtl;
    final langCode = locale.locale?.languageCode ?? 'en';
    return Scaffold(
      appBar: AppBar(
        title: Text(isRtl ? 'نتيجة المسح' : 'Scan Result'),
      ),
      body: Column(
        children: [
          // ── Source selector ────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  isRtl ? 'البحث في:' : 'Look up in:',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                DropdownButtonFormField<LookupSource>(
                  initialValue: _source,
                  decoration: const InputDecoration(
                    isDense: true,
                    prefixIcon: Icon(Icons.travel_explore_outlined),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: LookupSource.values
                      .map(
                        (s) => DropdownMenuItem<LookupSource>(
                          value: s,
                          child: Text(s.displayName(langCode)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) _changeSource(v);
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // ── Result body ────────────────────────────────────────────
          Expanded(
            child:
                _loading ? _buildLoading(isRtl) : _buildResult(isRtl, langCode),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading(bool isRtl) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(isRtl ? 'جاري البحث عن الباركود...' : 'Looking up barcode...'),
          const SizedBox(height: 8),
          Text(
            widget.code,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontFamily: 'RobotoMono',
                ),
          ),
          const SizedBox(height: 8),
          Text(
            isRtl
                ? 'المصدر: ${_source.displayName('ar')}'
                : 'Source: ${_source.displayName('en')}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          TextButton(
            onPressed: _openManualForm,
            child: Text(
                isRtl ? 'إلغاء والإدخال يدوياً' : 'Cancel and fill manually',),
          ),
        ],
      ),
    );
  }

  Widget _buildResult(bool isRtl, String langCode) {
    final lookup = _lookup;
    if (lookup == null) {
      return Center(
        child: Text(isRtl ? 'فشل البحث' : 'Lookup failed'),
      );
    }

    if (lookup.foundLocal && _source == LookupSource.auto) {
      final item = lookup.localItem!;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle,
                  size: 64, color: Theme.of(context).colorScheme.primary,),
              const SizedBox(height: 16),
              Text(isRtl ? 'وُجد في منتجاتك' : 'Found in your items',
                  style: Theme.of(context).textTheme.titleMedium,),
              const SizedBox(height: 24),
              Card(
                child: ListTile(
                  title: Text(item.displayName(langCode)),
                  subtitle: Text(item.barcode ?? ''),
                  trailing: Text(item.price == null
                      ? '—'
                      : item.currency.format(item.price!),),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _openExistingItem,
                icon: const Icon(Icons.edit),
                label: Text(isRtl ? 'فتح المنتج' : 'Open item'),
              ),
            ],
          ),
        ),
      );
    }

    if (lookup.foundOnline) {
      final product = lookup.onlineProduct!;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_done,
                  size: 64, color: Theme.of(context).colorScheme.primary,),
              const SizedBox(height: 16),
              Text(isRtl ? 'تم العثور على المنتج' : 'Item found',
                  style: Theme.of(context).textTheme.titleMedium,),
              const SizedBox(height: 8),
              Text(
                isRtl
                    ? 'المصدر: ${product.source}'
                    : 'Source: ${product.source}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(product.name,
                          style: Theme.of(context).textTheme.titleMedium,),
                      if (product.nameAr != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(product.nameAr!,
                              textDirection: TextDirection.rtl,),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        product.price == null
                            ? (isRtl ? 'السعر غير متوفر' : 'No price')
                            : '${product.currency} ${product.price!.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saveOnlineAsItem,
                icon: const Icon(Icons.save),
                label: Text(isRtl ? 'أضف إلى منتجاتي' : 'Add to my items'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _openManualForm,
                child: Text(isRtl ? 'تعديل قبل الحفظ' : 'Edit before saving'),
              ),
            ],
          ),
        ),
      );
    }

    // Not found
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off,
                size: 64, color: Theme.of(context).colorScheme.error,),
            const SizedBox(height: 16),
            Text(
              isRtl
                  ? 'غير موجود في ${_source.displayName('ar')}'
                  : 'Not found in ${_source.displayName('en')}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              isRtl
                  ? 'جرّب مصدراً آخر أو أدخل البيانات يدوياً'
                  : 'Try another source or fill the data manually',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                if (_source != LookupSource.auto)
                  FilledButton.tonalIcon(
                    onPressed: () => _changeSource(LookupSource.auto),
                    icon: const Icon(Icons.auto_awesome),
                    label: Text(isRtl ? 'ابحث في الكل' : 'Try all sources'),
                  ),
                FilledButton.icon(
                  onPressed: _openManualForm,
                  icon: const Icon(Icons.edit),
                  label: Text(isRtl ? 'أدخل يدوياً' : 'Fill manually'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
