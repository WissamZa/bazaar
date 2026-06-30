import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/database/dao/item_dao.dart';
import '../../core/database/dao/item_store_dao.dart';
import '../../core/database/dao/list_item_dao.dart';
import '../../core/database/dao/store_dao.dart';
import '../../core/constants/currencies.dart';
import '../../core/models/item.dart';
import '../../core/models/item_store.dart';
import '../../core/models/list_item.dart';
import '../../core/models/shopping_list.dart';
import '../../core/models/store.dart';
import '../../core/providers/locale_provider.dart';
import '../../widgets/currency_display.dart';
import '../../widgets/empty_state.dart';
import '../items/add_edit_item_screen.dart';

/// Detailed view of a single shopping list.
///
/// Each row shows the item name, its quantity, its unit price, and the
/// preferred store (if any). Tapping a row opens the Add/Edit item form so
/// the user can update the price or assign a different store. A long-press
/// opens a per-item menu with "Add price at another store" and "Remove from
/// list" actions.
class ListDetailScreen extends StatefulWidget {
  final ShoppingList list;
  const ListDetailScreen({super.key, required this.list});

  @override
  State<ListDetailScreen> createState() => _ListDetailScreenState();
}

class _ListDetailScreenState extends State<ListDetailScreen> {
  /// (item, list_item, preferred_store) for every row.
  List<RowData> _rows = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final pairs =
          await ListItemDao.instance.forListWithItems(widget.list.id!);
      final stores = await StoreDao.instance.all();

      // Build enriched row data with the preferred store and its price resolved.
      final rows = <RowData>[];
      for (final (item, li) in pairs) {
        final store = li.preferredStoreId == null
            ? null
            : stores.where((s) => s.id == li.preferredStoreId).firstOrNull;

        double? price;
        if (store != null) {
          final rel = await ItemStoreDao.instance
              .findByItemAndStore(item.id!, store.id!);
          price = rel?.price;
        }

        rows.add(RowData(
          item: item,
          listItem: li,
          preferredStore: store,
          preferredPrice: price,
        ));
      }
      if (!mounted) return;
      setState(() {
        _rows = rows;
      });
    } catch (e) {
      debugPrint('Error refreshing list details: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  double _computeTotal({bool checkedOnly = false}) {
    double sum = 0;
    for (final r in _rows) {
      if (checkedOnly && !r.listItem.isChecked) continue;
      final price = r.preferredPrice ?? 0;
      sum += price * r.listItem.quantity;
    }
    return sum;
  }

  int get _checkedCount => _rows.where((r) => r.listItem.isChecked).length;

  // ───────────────────────────── Actions ─────────────────────────────

  Future<void> _addItem() async {
    final locale = context.read<LocaleProvider>();
    final isRtl = locale.isRtl;
    final allItems = await ItemDao.instance.all();
    if (!mounted) return;
    if (allItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isRtl
                ? 'لا توجد منتجات. أضف منتجاً أولاً.'
                : 'No items yet. Add an item first.',
          ),
          action: SnackBarAction(
            label: isRtl ? 'إضافة منتج' : 'Add Item',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AddEditItemScreen()),
              );
              _refresh();
            },
          ),
        ),
      );
      return;
    }
    final stores = await StoreDao.instance.all();
    if (!mounted) return;
    final Item? picked = await showDialog<Item>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(isRtl ? 'أضف منتجاً إلى القائمة' : 'Add item to list'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: allItems.map((it) {
                final storeName = _storeNameForItem(it, stores, locale);
                return ListTile(
                  title:
                      Text(it.displayName(locale.locale?.languageCode ?? 'en')),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (it.barcode != null) Text(it.barcode!),
                      if (storeName != null) Text(storeName),
                    ],
                  ),
                  trailing: CurrencyDisplay(amount: it.price),
                  onTap: () => Navigator.pop(ctx, it),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
    if (picked == null || picked.id == null) return;

    final storePicked = await showDialog<Store>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(isRtl ? 'اختر المتجر' : 'Select Store'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: stores
                  .map((s) => ListTile(
                        title: Text(
                            s.displayName(locale.locale?.languageCode ?? 'en')),
                        onTap: () => Navigator.pop(ctx, s),
                      ))
                  .toList(),
            ),
          ),
        );
      },
    );

    if (storePicked == null) return;

    try {
      await ListItemDao.instance.insert(
        ListItem(
          listId: widget.list.id!,
          itemId: picked.id!,
          quantity: 1,
          preferredStoreId: storePicked.id,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isRtl ? 'العنصر موجود بالفعل في القائمة' : 'Item already in list',
          ),
        ),
      );
    }
    _refresh();
  }

  String? _storeNameForItem(
    Item item,
    List<Store> stores,
    LocaleProvider locale,
  ) {
    // For the lookup list, we can't easily know which stores sell it without a query.
    // But if we have the stores list, we could potentially check.
    // For now, let's just return null as the item doesn't have a "default" store.
    return null;
  }

  Future<void> _toggleCheck(ListItem li) async {
    await ListItemDao.instance.setChecked(li.id!, !li.isChecked);
    _refresh();
  }

  Future<void> _changeQuantity(ListItem li, int delta) async {
    final newQty = (li.quantity + delta).clamp(1, 999);
    await ListItemDao.instance.setQuantity(li.id!, newQty);
    _refresh();
  }

  /// Open the Add/Edit item form so the user can update price, store, etc.
  Future<void> _editItem(Item item) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AddEditItemScreen(item: item)),
    );
    _refresh();
  }

  /// Add a price for [item] at another store. Opens a dialog where the user
  /// picks a store and enters the price + optional URL. The result is
  /// upserted into the `item_store` table.
  Future<void> _addPriceAtStore(Item item) async {
    final locale = context.read<LocaleProvider>();
    final isRtl = locale.isRtl;
    final stores = await StoreDao.instance.all();
    final existing = await ItemStoreDao.instance.forItem(item.id!);

    if (!mounted) return;
    if (stores.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isRtl
                ? 'لا توجد متاجر. أضف متجراً أولاً.'
                : 'No stores yet. Add a store first.',
          ),
        ),
      );
      return;
    }

    final ctrl = TextEditingController();
    final urlCtrl = TextEditingController();
    Store selected = stores.first;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSt) {
            return AlertDialog(
              title: Text(
                isRtl ? 'أضف سعراً في متجر آخر' : 'Add price at another store',
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        item.displayName(locale.locale?.languageCode ?? 'en'),
                        style: Theme.of(ctx).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<Store>(
                        initialValue: selected,
                        decoration: InputDecoration(
                          labelText: isRtl ? 'المتجر' : 'Store',
                          prefixIcon: const Icon(Icons.storefront_outlined),
                        ),
                        items: stores
                            .map(
                              (s) => DropdownMenuItem(
                                value: s,
                                child: Text(
                                  s.displayName(
                                    locale.locale?.languageCode ?? 'en',
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setSt(() => selected = v);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: ctrl,
                        decoration: InputDecoration(
                          labelText: isRtl ? 'السعر' : 'Price',
                          prefixIcon: const Icon(Icons.attach_money),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: urlCtrl,
                        decoration: InputDecoration(
                          labelText: isRtl
                              ? 'رابط المنتج (اختياري)'
                              : 'Product URL (optional)',
                          prefixIcon: const Icon(Icons.link),
                        ),
                      ),
                      if (existing.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          isRtl
                              ? 'الأسعار الحالية لهذا المنتج:'
                              : 'Existing prices for this item:',
                          style: Theme.of(ctx).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 4),
                        ...existing.map((e) {
                          final s = stores.firstWhere(
                            (st) => st.id == e.storeId,
                            orElse: () =>
                                Store(name: '?', createdAt: DateTime.now()),
                          );
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    s.displayName(
                                      locale.locale?.languageCode ?? 'en',
                                    ),
                                  ),
                                ),
                                Text(
                                  e.price == null
                                      ? '—'
                                      : e.currency.format(e.price!),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(isRtl ? 'إلغاء' : 'Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(isRtl ? 'حفظ' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved != true) return;
    final price = double.tryParse(ctrl.text.trim());
    final is_ = ItemStore(
      itemId: item.id!,
      storeId: selected.id!,
      price: price,
      currency: item.currency,
      url: urlCtrl.text.trim().isEmpty ? null : urlCtrl.text.trim(),
    );
    await ItemStoreDao.instance.upsert(is_);

    // Update the item's "default" price if it had none or if the new
    // price is lower (cheap-store defaulting is a polite UX touch).
    if (item.price == null || (price != null && price < item.price!)) {
      await ItemDao.instance.update(
        item.copyWith(
          price: price,
          updatedAt: DateTime.now(),
        ),
      );
    }
    _refresh();
  }

  Future<void> _removeFromList(ListItem li) async {
    await ListItemDao.instance.delete(li.id!);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final isRtl = locale.isRtl;
    final langCode = locale.locale?.languageCode ?? 'en';
    final totalAll = _computeTotal();
    final totalChecked = _computeTotal(checkedOnly: true);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.list.displayName(langCode)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _rows.isEmpty
              ? EmptyState(
                  icon: Icons.shopping_cart,
                  title: isRtl ? 'القائمة فارغة' : 'List is empty',
                  hint: isRtl
                      ? 'أضف منتجات لبدء التسوق'
                      : 'Add items to start shopping',
                  actionLabel: isRtl ? 'أضف منتجاً' : 'Add item',
                  onAction: _addItem,
                )
              : Column(
                  children: [
                    _SummaryBar(
                      totalItems: _rows.length,
                      checkedItems: _checkedCount,
                      totalAll: totalAll,
                      totalChecked: totalChecked,
                      isRtl: isRtl,
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 96),
                        itemCount: _rows.length,
                        itemBuilder: (_, i) =>
                            _buildRow(_rows[i], isRtl, langCode),
                      ),
                    ),
                    _TotalBar(
                      totalAll: totalAll,
                      totalChecked: totalChecked,
                      itemCount: _rows.length,
                      isRtl: isRtl,
                    ),
                  ],
                ),
    );
  }

  Widget _buildRow(RowData data, bool isRtl, String langCode) {
    final item = data.item;
    final li = data.listItem;
    final store = data.preferredStore;
    final price = data.preferredPrice;
    final lineTotal = (price ?? 0) * li.quantity;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Checkbox
            Checkbox(
              value: li.isChecked,
              onChanged: (_) => _toggleCheck(li),
            ),
            // Main content
            Expanded(
              child: InkWell(
                onTap: () => _editItem(item),
                onLongPress: () => _showRowMenu(data, isRtl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.displayName(langCode),
                      style: li.isChecked
                          ? const TextStyle(
                              decoration: TextDecoration.lineThrough,
                              color: Colors.grey,
                              fontWeight: FontWeight.w600,
                            )
                          : const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (price != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.attach_money,
                                size: 14,
                                color: Colors.grey,
                              ),
                              CurrencyDisplay(
                                amount: price,
                                overrideCurrency: item.currency,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          )
                        else
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.attach_money,
                                size: 14,
                                color: Colors.grey,
                              ),
                              Text(
                                isRtl ? 'سعر غير محدد' : 'No price',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: Colors.grey),
                              ),
                            ],
                          ),
                        if (store != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.storefront_outlined,
                                size: 14,
                                color: Colors.grey,
                              ),
                              Text(
                                store.displayName(langCode),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: Colors.grey),
                              ),
                            ],
                          )
                        else
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.storefront_outlined,
                                size: 14,
                                color: Colors.grey,
                              ),
                              Text(
                                isRtl ? 'لا متجر' : 'No store',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: Colors.grey),
                              ),
                            ],
                          ),
                        if (item.barcode != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.qr_code,
                                size: 14,
                                color: Colors.grey,
                              ),
                              Text(
                                item.barcode!,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: Colors.grey),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isRtl
                          ? 'الإجمالي: ${lineTotal.toStringAsFixed(2)}'
                          : 'Line total: ${lineTotal.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            // Quantity stepper
            _QuantityStepper(
              quantity: li.quantity,
              disabled: li.isChecked,
              onDec: li.isChecked ? null : () => _changeQuantity(li, -1),
              onInc: li.isChecked ? null : () => _changeQuantity(li, 1),
            ),
            // Per-item menu
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () => _showRowMenu(data, isRtl),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changePreferredStore(ListItem li) async {
    final locale = context.read<LocaleProvider>();
    final isRtl = locale.isRtl;
    final langCode = locale.locale?.languageCode ?? 'en';
    final stores = await StoreDao.instance.all();

    final Store? picked = await showDialog<Store>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isRtl ? 'اختر المتجر' : 'Select Store'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: stores
                .map((s) => ListTile(
                      title: Text(s.displayName(langCode)),
                      selected: s.id == li.preferredStoreId,
                      onTap: () => Navigator.pop(ctx, s),
                    ))
                .toList(),
          ),
        ),
      ),
    );

    if (picked != null) {
      await ListItemDao.instance.update(
        li.copyWith(preferredStoreId: picked.id),
      );
      _refresh();
    }
  }

  void _showRowMenu(RowData data, bool isRtl) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: Text(isRtl ? 'تعديل المنتج' : 'Edit item'),
              onTap: () {
                Navigator.pop(ctx);
                _editItem(data.item);
              },
            ),
            ListTile(
              leading: const Icon(Icons.store),
              title: Text(isRtl ? 'تغيير المتجر' : 'Change store'),
              onTap: () {
                Navigator.pop(ctx);
                _changePreferredStore(data.listItem);
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_business),
              title: Text(
                isRtl ? 'أضف سعراً في متجر آخر' : 'Add price at another store',
              ),
              onTap: () {
                Navigator.pop(ctx);
                _addPriceAtStore(data.item);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: Text(isRtl ? 'إزالة من القائمة' : 'Remove from list'),
              onTap: () async {
                Navigator.pop(ctx);
                await _removeFromList(data.listItem);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// Helper bundle so the ListView doesn't re-resolve the preferred store
/// for every row on every rebuild.
class RowData {
  final Item item;
  final ListItem listItem;
  final Store? preferredStore;
  final double? preferredPrice;
  const RowData({
    required this.item,
    required this.listItem,
    required this.preferredStore,
    this.preferredPrice,
  });
}

// ─────────────────────────── Sub-widgets ────────────────────────────────

class _SummaryBar extends StatelessWidget {
  final int totalItems;
  final int checkedItems;
  final double totalAll;
  final double totalChecked;
  final bool isRtl;

  const _SummaryBar({
    required this.totalItems,
    required this.checkedItems,
    required this.totalAll,
    required this.totalChecked,
    required this.isRtl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        children: [
          Expanded(
            child: _Stat(
              icon: Icons.checklist,
              label: isRtl ? 'المنتجات' : 'Items',
              value: isRtl ? '$totalItems' : '$totalItems ($checkedItems ✓)',
            ),
          ),
          Container(
            width: 1,
            height: 32,
            color: Theme.of(context).dividerColor,
          ),
          Expanded(
            child: _Stat(
              icon: Icons.shopping_cart_checkout,
              label: isRtl ? 'الإجمالي' : 'Total',
              child: CurrencyDisplay(
                amount: totalAll,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final Widget? child;

  const _Stat({
    required this.icon,
    required this.label,
    this.value,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            if (child != null) child!,
            if (child == null)
              Text(
                value ?? '',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
          ],
        ),
      ],
    );
  }
}

class _TotalBar extends StatelessWidget {
  final double totalAll;
  final double totalChecked;
  final int itemCount;
  final bool isRtl;

  const _TotalBar({
    required this.totalAll,
    required this.totalChecked,
    required this.itemCount,
    required this.isRtl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isRtl ? 'الإجمالي (المحدد)' : 'Total (checked)',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                CurrencyDisplay(
                  amount: totalChecked,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  isRtl
                      ? 'الإجمالي ($itemCount عنصر)'
                      : 'Total ($itemCount items)',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                CurrencyDisplay(
                  amount: totalAll,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  final int quantity;
  final bool disabled;
  final VoidCallback? onDec;
  final VoidCallback? onInc;

  const _QuantityStepper({
    required this.quantity,
    required this.disabled,
    required this.onDec,
    required this.onInc,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: disabled ? null : onDec,
          visualDensity: VisualDensity.compact,
        ),
        Text(
          '$quantity',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: disabled ? null : onInc,
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}
