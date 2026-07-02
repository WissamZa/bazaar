import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/currencies.dart';
import '../../core/database/dao/item_dao.dart';
import '../../core/database/dao/item_store_dao.dart';
import '../../core/database/dao/store_dao.dart';
import '../../core/models/item.dart';
import '../../core/models/item_store.dart';
import '../../core/models/store.dart';
import '../../core/providers/locale_provider.dart';
import '../../widgets/currency_display.dart';
import '../items/add_edit_item_screen.dart';
import 'add_edit_store_screen.dart';

class StoreDetailScreen extends StatefulWidget {
  final Store store;
  const StoreDetailScreen({super.key, required this.store});

  @override
  State<StoreDetailScreen> createState() => _StoreDetailScreenState();
}

class _StoreDetailScreenState extends State<StoreDetailScreen> {
  /// Pairs of (item, per-store relation). The relation may be null when the
  /// item is shown here only because this is the default store — in that
  /// case the price falls back to `item.price`.
  final List<_StoreItemRow> _rows = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() => _loading = true);
    try {
      final storeId = widget.store.id!;
      final relations = await ItemStoreDao.instance.forStore(storeId);

      // Build rows from explicit relations first.
      final seenItemIds = <int>{};
      final rows = <_StoreItemRow>[];
      for (final r in relations) {
        final item = await ItemDao.instance.findById(r.itemId);
        if (item != null) {
          rows.add(_StoreItemRow(item: item, relation: r));
          seenItemIds.add(item.id!);
        }
      }

      // If this is the DEFAULT store, also include every item that has no
      // store link at all — so the user always sees their items somewhere.
      final isDefault = await StoreDao.instance.isDefaultStore(storeId);
      if (isDefault) {
        final allItems = await ItemDao.instance.all();
        for (final item in allItems) {
          if (item.id == null) continue;
          if (seenItemIds.contains(item.id!)) continue;
          // Check whether the item is linked to ANY store.
          final links = await ItemStoreDao.instance.forItem(item.id!);
          if (links.isEmpty) {
            rows.add(_StoreItemRow(item: item, relation: null));
          }
        }
      }

      // Sort by name so the list is stable.
      final langCode =
          context.read<LocaleProvider>().locale?.languageCode ?? 'en';
      rows.sort((a, b) =>
          a.item.displayName(langCode).toLowerCase().compareTo(
              b.item.displayName(langCode).toLowerCase()));

      if (!mounted) return;
      setState(() {
        _rows
          ..clear()
          ..addAll(rows);
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading store items: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final isRtl = locale.isRtl;
    final langCode = locale.locale?.languageCode ?? 'en';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.store.displayName(langCode)),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') {
                Navigator.of(context)
                    .push(
                      MaterialPageRoute(
                        builder: (_) =>
                            AddEditStoreScreen(store: widget.store),
                      ),
                    )
                    .then((_) => _loadItems());
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'edit',
                child: Text(isRtl ? 'تعديل' : 'Edit'),
              ),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _rows.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.inventory_2_outlined,
                          size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        isRtl
                            ? 'لا توجد منتجات في هذا المتجر'
                            : 'No items in this store',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadItems,
                  child: ListView.builder(
                    itemCount: _rows.length,
                    itemBuilder: (_, i) {
                      final row = _rows[i];
                      final item = row.item;
                      // Prefer the per-store price; fall back to the item's
                      // own price field; treat both as null → CurrencyDisplay
                      // shows `⃁ 0.00`.
                      final price = row.relation?.price ?? item.price;
                      // ItemStore.currency is already an AppCurrency enum,
                      // so we can use it directly when a relation exists;
                      // otherwise fall back to the item's currency.
                      final currency =
                          row.relation?.currency ?? item.currency;

                      return Card(
                        child: ListTile(
                          leading: item.imageUrl != null &&
                                  item.imageUrl!.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.network(
                                    item.imageUrl!,
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        _placeholderIcon(),
                                  ),
                                )
                              : _placeholderIcon(),
                          title: Text(item.displayName(langCode)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (item.brand != null &&
                                  item.brand!.isNotEmpty)
                                Text(
                                  '${isRtl ? 'الماركة: ' : 'Brand: '}${item.brand}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              if (item.barcode != null)
                                Text(
                                  'Barcode: ${item.barcode}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                            ],
                          ),
                          trailing: CurrencyDisplay(
                            amount: price,
                            overrideCurrency: currency,
                          ),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => AddEditItemScreen(item: item),
                            ),
                          ).then((_) => _loadItems()),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _placeholderIcon() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(
        Icons.inventory_2_outlined,
        size: 24,
        color: Theme.of(context).colorScheme.outline,
      ),
    );
  }
}

class _StoreItemRow {
  final Item item;
  final ItemStore? relation;
  const _StoreItemRow({required this.item, this.relation});
}
