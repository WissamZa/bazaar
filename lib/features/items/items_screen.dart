import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/database/dao/item_dao.dart';
import '../../core/models/item.dart';
import '../../core/providers/data_change_notifier.dart';
import '../../core/providers/locale_provider.dart';
import '../../widgets/currency_display.dart';
import '../../widgets/empty_state.dart';
import 'add_edit_item_screen.dart';

enum SortOption {
  newest,
  oldest,
  priceLowHigh,
  priceHighLow,
  nameAZ,
  nameZA,
}

enum GroupOption {
  none,
  brand,
  category,
}

class ItemsScreen extends StatefulWidget {
  const ItemsScreen({super.key});

  @override
  State<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends State<ItemsScreen> {
  final _searchCtrl = TextEditingController();
  List<Item> _items = [];
  /// Effective price for each item, keyed by item.id. Populated by
  /// `_refresh()` via `ItemDao.effectivePriceFor()` — preferred store's
  /// price if set, otherwise the lowest non-null store price, otherwise
  /// the legacy `item.price` field.
  final Map<int, double?> _effectivePrices = {};
  bool _loading = true;
  String _query = '';
  SortOption _sortOption = SortOption.newest;
  GroupOption _groupOption = GroupOption.none;

  @override
  void initState() {
    super.initState();
    _refresh();
    // Listen for any data change (item added/edited/deleted, store link
    // changed, price updated, etc.) and refresh the list when it happens.
    // This catches both the FAB add-item flow (which doesn't go through
    // _openAddEdit) and edits made from other screens.
    DataChangeNotifier.instance.addListener(_onDataChanged);
  }

  @override
  void dispose() {
    DataChangeNotifier.instance.removeListener(_onDataChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) _refresh();
  }

  Future<void> _refresh({String? query}) async {
    setState(() => _loading = true);
    try {
      final q = query ?? _query;
      var items = q.isEmpty
          ? await ItemDao.instance.all()
          : await ItemDao.instance.search(q);

      // Fetch the effective price for each item (preferred store's price,
      // else lowest, else legacy item.price). Done in parallel for speed.
      _effectivePrices.clear();
      final priceFutures = items
          .where((i) => i.id != null)
          .map((i) => ItemDao.instance
              .effectivePriceFor(i)
              .then((p) => MapEntry(i.id!, p)));
      final priceEntries = await Future.wait(priceFutures);
      for (final entry in priceEntries) {
        _effectivePrices[entry.key] = entry.value;
      }

      // Apply sorting — use the effective price for price-based sorts so
      // items are ordered by what the user actually sees, not by the
      // legacy `item.price` field which is usually null.
      items = List.from(items);
      double _priceOf(Item i) =>
          i.id != null ? (_effectivePrices[i.id!] ?? i.price ?? 0) : (i.price ?? 0);
      switch (_sortOption) {
        case SortOption.newest:
          items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          break;
        case SortOption.oldest:
          items.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          break;
        case SortOption.priceLowHigh:
          items.sort((a, b) => _priceOf(a).compareTo(_priceOf(b)));
          break;
        case SortOption.priceHighLow:
          items.sort((a, b) => _priceOf(b).compareTo(_priceOf(a)));
          break;
        case SortOption.nameAZ:
          items.sort(
            (a, b) => a.nameEn.toLowerCase().compareTo(b.nameEn.toLowerCase()),
          );
          break;
        case SortOption.nameZA:
          items.sort(
            (a, b) => b.nameEn.toLowerCase().compareTo(a.nameEn.toLowerCase()),
          );
          break;
      }

      _items = items;
    } catch (e) {
      debugPrint('Error refreshing items: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    return Column(
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
                    hintText:
                        locale.isRtl ? 'ابحث عن منتجات...' : 'Search items...',
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
              IconButton(
                icon: const Icon(Icons.grid_view),
                onPressed: () => _showGroupMenu(context, locale),
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
                      title:
                          locale.isRtl ? 'لا توجد منتجات بعد' : 'No items yet',
                      hint: locale.isRtl
                          ? 'اضغط على زر + لإضافة أول منتج'
                          : 'Tap the + button to add your first item',
                      actionLabel: locale.isRtl ? 'إضافة منتج' : 'Add Item',
                      onAction: () => _openAddEdit(),
                    )
                  : RefreshIndicator(
                      onRefresh: _refresh,
                      child: _buildList(context, locale),
                    ),
        ),
      ],
    );
  }

  Widget _buildList(BuildContext context, LocaleProvider locale) {
    final isRtl = locale.isRtl;

    if (_groupOption == GroupOption.none) {
      return ListView.builder(
        itemCount: _items.length,
        itemBuilder: (_, i) =>
            _buildItemDismissible(context, _items[i], i, locale),
      );
    }

    // Group items
    final Map<String, List<Item>> grouped = {};
    for (final item in _items) {
      String key;
      if (_groupOption == GroupOption.brand) {
        key = item.brand?.trim().toUpperCase() ??
            (isRtl ? 'بدون ماركة' : 'No Brand');
      } else {
        key = item.categoryId?.toString() ??
            (isRtl ? 'بدون تصنيف' : 'No Category');
      }
      grouped.putIfAbsent(key, () => []).add(item);
    }

    final keys = grouped.keys.toList()..sort();

    return ListView(
      children: keys.map((key) {
        final groupItems = grouped[key]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              title: Text(key,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              tileColor: Theme.of(context).colorScheme.surfaceVariant,
            ),
            ...groupItems.map((item) => _buildItemDismissible(
                context, item, _items.indexOf(item), locale)),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildItemDismissible(
      BuildContext context, Item item, int index, LocaleProvider locale) {
    final isRtl = locale.isRtl;
    final langCode = locale.locale?.languageCode ?? 'en';

    return Dismissible(
      key: ValueKey(item.id ?? index),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(isRtl ? 'تأكيد الحذف؟' : 'Confirm delete?'),
                content: Text(isRtl
                    ? 'لا يمكن التراجع عن هذا الإجراء.'
                    : 'This action cannot be undone.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(isRtl ? 'إلغاء' : 'Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(isRtl ? 'حذف' : 'Delete'),
                  ),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) async {
        await ItemDao.instance.delete(item.id!);
        _items.removeWhere((it) => it.id == item.id);
        setState(() {});
        // Notify other screens (Stores detail, Lists) that an item was
        // deleted so their lists stay in sync.
        DataChangeNotifier.instance.notify(tag: 'item-deleted');
      },
      child: ListTile(
        leading: item.imageUrl != null && item.imageUrl!.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  item.imageUrl!,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      _placeholderIcon(),
                ),
              )
            : _placeholderIcon(),
        title: Text(item.displayName(langCode)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.brand != null && item.brand!.isNotEmpty)
              Text('${isRtl ? 'الماركة: ' : 'Brand: '}${item.brand}',
                  style: Theme.of(context).textTheme.bodySmall),
            if (item.barcode != null)
              Text('Barcode: ${item.barcode}',
                  style: Theme.of(context).textTheme.bodySmall),
            Text(
              '${isRtl ? 'أضيف في ' : 'Added on '}${item.createdAt.toLocal().toString().split(' ')[0]}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
        trailing: CurrencyDisplay(
          // Use the effective price (preferred store's price, else lowest,
          // else 0) — NOT item.price which is always null in the new
          // per-store-pricing model.
          amount: item.id != null
              ? (_effectivePrices[item.id!] ?? item.price)
              : item.price,
        ),
        onTap: () => _openAddEdit(item: item),
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

  void _showGroupMenu(BuildContext context, LocaleProvider locale) {
    final isRtl = locale.isRtl;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              isRtl ? 'تجميع المنتجات' : 'Group Items',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.list),
            title: Text(isRtl ? 'بدون تجميع' : 'No Grouping'),
            onTap: () {
              setState(() => _groupOption = GroupOption.none);
              Navigator.pop(ctx);
            },
          ),
          ListTile(
            leading: const Icon(Icons.branding_watermark),
            title: Text(isRtl ? 'حسب الماركة' : 'By Brand'),
            onTap: () {
              setState(() => _groupOption = GroupOption.brand);
              Navigator.pop(ctx);
            },
          ),
          ListTile(
            leading: const Icon(Icons.category),
            title: Text(isRtl ? 'حسب التصنيف' : 'By Category'),
            onTap: () {
              setState(() => _groupOption = GroupOption.category);
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

  /// Square grey icon shown when an item has no image or the image fails
  /// to load. Keeps the ListTile layout stable so the row doesn't shift
  /// when images finish loading later.
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
