import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/currencies.dart';
import '../../core/database/dao/item_dao.dart';
import '../../core/database/dao/list_item_dao.dart';
import '../../core/database/dao/store_dao.dart';
import '../../core/models/item.dart';
import '../../core/models/list_item.dart';
import '../../core/models/shopping_list.dart';
import '../../core/models/store.dart';
import '../../core/providers/currency_provider.dart';
import '../../core/providers/locale_provider.dart';
import '../../core/services/share_service.dart';
import '../../widgets/currency_display.dart';
import '../../widgets/empty_state.dart';
import '../items/add_edit_item_screen.dart';
import 'add_edit_list_screen.dart';

class ListDetailScreen extends StatefulWidget {
  final ShoppingList list;
  const ListDetailScreen({super.key, required this.list});

  @override
  State<ListDetailScreen> createState() => _ListDetailScreenState();
}

class _ListDetailScreenState extends State<ListDetailScreen> {
  List<(Item, ListItem)> _rows = [];
  List<Store> _stores = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    _rows = await ListItemDao.instance.forListWithItems(widget.list.id!);
    _stores = await StoreDao.instance.all();
    if (!mounted) return;
    setState(() => _loading = false);
  }

  double _computeTotal(bool checkedOnly) {
    double sum = 0;
    for (final (item, li) in _rows) {
      if (checkedOnly && !li.isChecked) continue;
      final price = item.price ?? 0;
      sum += price * li.quantity;
    }
    return sum;
  }

  Future<void> _addItem() async {
    // Show a quick picker of existing items.
    final allItems = await ItemDao.instance.all();
    if (!mounted) return;
    if (allItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.read<LocaleProvider>().isRtl
              ? 'لا توجد منتجات. أضف منتجاً أولاً.'
              : 'No items yet. Add an item first.'),
          action: SnackBarAction(
            label: context.read<LocaleProvider>().isRtl ? 'إضافة منتج' : 'Add Item',
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
    final Item? picked = await showDialog<Item>(
      context: context,
      builder: (ctx) {
        final locale = context.read<LocaleProvider>();
        return AlertDialog(
          title: Text(locale.isRtl ? 'أضف منتجاً إلى القائمة' : 'Add item to list'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: allItems.length,
              itemBuilder: (_, i) {
                final it = allItems[i];
                return ListTile(
                  title: Text(it.displayName(locale.locale?.languageCode ?? 'en')),
                  subtitle: it.barcode == null ? null : Text(it.barcode!),
                  trailing: CurrencyDisplay(amount: it.price),
                  onTap: () => Navigator.pop(ctx, it),
                );
              },
            ),
          ),
        );
      },
    );
    if (picked == null || picked.id == null) return;
    try {
      await ListItemDao.instance.insert(ListItem(
        listId: widget.list.id!,
        itemId: picked.id!,
        quantity: 1,
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.read<LocaleProvider>().isRtl
            ? 'العنصر موجود بالفعل في القائمة'
            : 'Item already in list'),
      ));
    }
    _refresh();
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

  Future<void> _editList() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddEditListScreen(list: widget.list),
      ),
    );
    _refresh();
  }

  Future<void> _shareList() async {
    final listItems = await ListItemDao.instance.forList(widget.list.id!);
    await ShareService.instance.exportList(widget.list, listItems);
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final currencyProv = context.watch<CurrencyProvider>();
    final isRtl = locale.isRtl;
    final totalAll = _computeTotal(false);
    final totalChecked = _computeTotal(true);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.list.displayName(locale.locale?.languageCode ?? 'en')),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: isRtl ? 'تعديل القائمة' : 'Edit List',
            onPressed: _editList,
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: isRtl ? 'مشاركة' : 'Share',
            onPressed: _shareList,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _rows.isEmpty
              ? EmptyState(
                  icon: Icons.add_shopping_cart,
                  title: isRtl ? 'القائمة فارغة' : 'List is empty',
                  hint: isRtl
                      ? 'أضف منتجات لبدء التسوق'
                      : 'Add items to start shopping',
                  actionLabel: isRtl ? 'أضف منتجاً' : 'Add item',
                  onAction: _addItem,
                )
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        itemCount: _rows.length,
                        itemBuilder: (_, i) {
                          final (item, li) = _rows[i];
                          return CheckboxListTile(
                            value: li.isChecked,
                            onChanged: (_) => _toggleCheck(li),
                            secondary: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline),
                                  onPressed: li.isChecked
                                      ? null
                                      : () => _changeQuantity(li, -1),
                                ),
                                Text('${li.quantity}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline),
                                  onPressed: li.isChecked
                                      ? null
                                      : () => _changeQuantity(li, 1),
                                ),
                              ],
                            ),
                            title: Text(
                              item.displayName(locale.locale?.languageCode ?? 'en'),
                              style: li.isChecked
                                  ? const TextStyle(
                                      decoration: TextDecoration.lineThrough,
                                      color: Colors.grey)
                                  : null,
                            ),
                            subtitle: CurrencyDisplay(
                              amount: (item.price ?? 0) * li.quantity,
                              overrideCurrency: item.currency,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                          );
                        },
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        border: Border(
                          top: BorderSide(
                              color: Theme.of(context).dividerColor),
                        ),
                      ),
                      child: SafeArea(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(isRtl ? 'الإجمالي (المحدد)' : 'Total (checked)',
                                    style:
                                        Theme.of(context).textTheme.bodySmall),
                                CurrencyDisplay(
                                  amount: totalChecked,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color:
                                            Theme.of(context).colorScheme.primary,
                                      ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(isRtl ? 'الإجمالي' : 'Total',
                                    style:
                                        Theme.of(context).textTheme.bodySmall),
                                CurrencyDisplay(
                                  amount: totalAll,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addItem,
        child: const Icon(Icons.add),
      ),
    );
  }
}
