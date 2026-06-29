import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/database/dao/item_dao.dart';
import '../../core/models/item.dart';
import '../../core/providers/locale_provider.dart';
import '../../widgets/currency_display.dart';
import '../../widgets/empty_state.dart';
import 'add_edit_item_screen.dart';
import '../scanner/scanner_screen.dart';
import '../scanner/scan_result_screen.dart';

enum SortOption {
  newest,
  oldest,
  priceLowHigh,
  priceHighLow,
  nameAZ,
  nameZA,
}

class ItemsScreen extends StatefulWidget {
  const ItemsScreen({super.key});

  @override
  State<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends State<ItemsScreen> {
  final _searchCtrl = TextEditingController();
  List<Item> _items = [];
  bool _loading = true;
  String _query = '';
  SortOption _sortOption = SortOption.newest;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh({String? query}) async {
    setState(() => _loading = true);
    final q = query ?? _query;
    var items = q.isEmpty
        ? await ItemDao.instance.all()
        : await ItemDao.instance.search(q);

    // Apply sorting
    items = List.from(items);
    switch (_sortOption) {
      case SortOption.newest:
        items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case SortOption.oldest:
        items.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case SortOption.priceLowHigh:
        items.sort((a, b) => (a.price ?? 0).compareTo(b.price ?? 0));
        break;
      case SortOption.priceHighLow:
        items.sort((a, b) => (b.price ?? 0).compareTo(a.price ?? 0));
        break;
      case SortOption.nameAZ:
        items.sort(
            (a, b) => a.nameEn.toLowerCase().compareTo(b.nameEn.toLowerCase()));
        break;
      case SortOption.nameZA:
        items.sort(
            (a, b) => b.nameEn.toLowerCase().compareTo(a.nameEn.toLowerCase()));
        break;
    }

    _items = items;
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _openScanner() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const ScannerScreen()),
    );
    if (code == null) return;
    // Push the lookup flow — it handles local-DB hit, online scrape, and
    // prefilling the Add/Edit form.
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ScanResultScreen(code: code)),
    );
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: locale.isRtl
                          ? 'ابحث عن منتجات...'
                          : 'Search items...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchCtrl.clear();
                                _query = '';
                                _refresh();
                              },
                            ),
                    ),
                    onChanged: (v) {
                      _query = v;
                      _refresh(query: v);
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.sort),
                  onPressed: () => _showSortMenu(context, locale),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? EmptyState(
                        icon: Icons.inventory_2_outlined,
                        title: locale.isRtl
                            ? 'لا توجد منتجات بعد'
                            : 'No items yet',
                        hint: locale.isRtl
                            ? 'اضغط على زر + لإضافة أول منتج'
                            : 'Tap the + button to add your first item',
                        actionLabel: locale.isRtl ? 'إضافة منتج' : 'Add Item',
                        onAction: () => _openAddEdit(),
                      )
                    : RefreshIndicator(
                        onRefresh: _refresh,
                        child: ListView.builder(
                          itemCount: _items.length,
                          itemBuilder: (_, i) {
                            final item = _items[i];
                            return Dismissible(
                              key: ValueKey(item.id ?? i),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                color: Colors.red,
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 24),
                                child: const Icon(Icons.delete,
                                    color: Colors.white),
                              ),
                              confirmDismiss: (_) async {
                                return await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: Text(locale.isRtl
                                            ? 'تأكيد الحذف؟'
                                            : 'Confirm delete?'),
                                        content: Text(locale.isRtl
                                            ? 'لا يمكن التراجع عن هذا الإجراء.'
                                            : 'This action cannot be undone.'),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, false),
                                            child: Text(locale.isRtl
                                                ? 'إلغاء'
                                                : 'Cancel'),
                                          ),
                                          FilledButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, true),
                                            child: Text(locale.isRtl
                                                ? 'حذف'
                                                : 'Delete'),
                                          ),
                                        ],
                                      ),
                                    ) ??
                                    false;
                              },
                              onDismissed: (_) async {
                                await ItemDao.instance.delete(item.id!);
                                _items.removeAt(i);
                                setState(() {});
                              },
                              child: ListTile(
                                title: Text(item.displayName(
                                    locale.locale?.languageCode ?? 'en')),
                                subtitle: item.barcode == null
                                    ? null
                                    : Text(
                                        ' Barcode: ${item.barcode}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                trailing: CurrencyDisplay(amount: item.price),
                                onTap: () => _openAddEdit(item: item),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'scan_fab',
            onPressed: _openScanner,
            child: const Icon(Icons.qr_code_scanner),
          ),
          const SizedBox(width: 12),
          FloatingActionButton(
            heroTag: 'add_fab',
            onPressed: () => _openAddEdit(),
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  void _showSortMenu(BuildContext context, LocaleProvider locale) {
    final isRtl = locale.isRtl;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              isRtl ? 'ترتيب المنتجات' : 'Sort Items',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.date_range),
            title: Text(isRtl ? 'الأحدث أولاً' : 'Newest First'),
            onTap: () {
              setState(() => _sortOption = SortOption.newest);
              _refresh();
              Navigator.pop(ctx);
            },
          ),
          ListTile(
            leading: const Icon(Icons.date_range),
            title: Text(isRtl ? 'الأقدم أولاً' : 'Oldest First'),
            onTap: () {
              setState(() => _sortOption = SortOption.oldest);
              _refresh();
              Navigator.pop(ctx);
            },
          ),
          ListTile(
            leading: const Icon(Icons.price_check),
            title:
                Text(isRtl ? 'السعر: من الأقل للأعلى' : 'Price: Low to High'),
            onTap: () {
              setState(() => _sortOption = SortOption.priceLowHigh);
              _refresh();
              Navigator.pop(ctx);
            },
          ),
          ListTile(
            leading: const Icon(Icons.price_check),
            title:
                Text(isRtl ? 'السعر: من الأعلى للأقل' : 'Price: High to Low'),
            onTap: () {
              setState(() => _sortOption = SortOption.priceHighLow);
              _refresh();
              Navigator.pop(ctx);
            },
          ),
          ListTile(
            leading: const Icon(Icons.sort_by_alpha),
            title: Text(isRtl ? 'الاسم: أ-ي' : 'Name: A-Z'),
            onTap: () {
              setState(() => _sortOption = SortOption.nameAZ);
              _refresh();
              Navigator.pop(ctx);
            },
          ),
          ListTile(
            leading: const Icon(Icons.sort_by_alpha),
            title: Text(isRtl ? 'الاسم: ي-أ' : 'Name: Z-A'),
            onTap: () {
              setState(() => _sortOption = SortOption.nameZA);
              _refresh();
              Navigator.pop(ctx);
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _openAddEdit({Item? item}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddEditItemScreen(item: item),
      ),
    );
    _refresh();
  }
}
