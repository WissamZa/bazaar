import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/database/dao/item_dao.dart';
import '../../core/database/dao/item_store_dao.dart';
import '../../core/database/dao/list_item_dao.dart';
import '../../core/database/dao/shopping_list_dao.dart';
import '../../core/database/dao/store_dao.dart';
import '../../core/models/item.dart';
import '../../core/models/item_store.dart';
import '../../core/models/shopping_list.dart';
import '../../core/models/store.dart';
import '../../core/providers/locale_provider.dart';
import '../../core/providers/user_provider.dart';
import '../../widgets/currency_display.dart';
import '../../widgets/empty_state.dart';
import '../shopping_lists/list_detail_screen.dart';
import '../shopping_lists/lists_screen.dart';
import '../stores/stores_screen.dart';

/// Analytics dashboard shown as the first tab in [HomeShell].
///
/// Surfaces quick KPIs (total lists, items, stores), recent lists, the
/// top stores by # of items tracked, and the most expensive items.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  _Analytics? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final data = await _Analytics.load();
    if (!mounted) return;
    setState(() {
      _data = data;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final user = context.watch<UserProvider>();
    final isRtl = locale.isRtl;
    final langCode = locale.locale?.languageCode ?? 'en';

    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: _data == null || _data!.isEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: 80),
                        EmptyState(
                          icon: Icons.analytics_outlined,
                          title: isRtl ? 'لا توجد بيانات بعد' : 'No data yet',
                          hint: isRtl
                              ? 'أضف منتجات وقوائم ومتاجر لرؤية التحليلات'
                              : 'Add items, lists and stores to see analytics',
                        ),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                      children: [
                        _GreetingCard(
                          username: user.username ?? '',
                          isRtl: isRtl,
                          data: _data!,
                        ),
                        const SizedBox(height: 12),
                        _KpiGrid(data: _data!, isRtl: isRtl),
                        const SizedBox(height: 16),
                        _SectionHeader(
                          icon: Icons.checklist,
                          title: isRtl ? 'أحدث قوائم التسوق' : 'Recent lists',
                          isRtl: isRtl,
                          onSeeAll: () => _push(const ListsScreen()),
                        ),
                        const SizedBox(height: 6),
                        ..._data!.recentLists.map(
                          (l) => _ListTileCard(
                            list: l,
                            itemCount: _data!.itemsPerList[l.id ?? -1] ?? 0,
                            total: _data!.totalPerList[l.id ?? -1] ?? 0,
                            isRtl: isRtl,
                            langCode: langCode,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _SectionHeader(
                          icon: Icons.storefront,
                          title: isRtl
                              ? 'المتاجر حسب عدد المنتجات'
                              : 'Stores by item count',
                          isRtl: isRtl,
                          onSeeAll: () => _push(const StoresScreen()),
                        ),
                        const SizedBox(height: 6),
                        if (_data!.storeItemCounts.isEmpty)
                          _EmptyHint(
                            isRtl: isRtl,
                            text: isRtl ? 'لا توجد متاجر بعد' : 'No stores yet',
                          )
                        else
                          ..._data!.storeItemCounts.entries.map(
                            (e) => _StoreBarRow(
                              storeName: e.key,
                              count: e.value,
                              share: e.value / _data!.maxStoreCount,
                              isRtl: isRtl,
                            ),
                          ),
                        const SizedBox(height: 16),
                        _SectionHeader(
                          icon: Icons.trending_up,
                          title: isRtl
                              ? 'أغلى 5 منتجات'
                              : 'Top 5 most expensive items',
                          isRtl: isRtl,
                        ),
                        const SizedBox(height: 6),
                        if (_data!.mostExpensive.isEmpty)
                          _EmptyHint(
                            isRtl: isRtl,
                            text: isRtl ? 'لا توجد أسعار بعد' : 'No prices yet',
                          )
                        else
                          ..._data!.mostExpensive.asMap().entries.map(
                                (e) => _ItemRankRow(
                                  rank: e.key + 1,
                                  item: e.value,
                                  isRtl: isRtl,
                                  langCode: langCode,
                                ),
                              ),
                        const SizedBox(height: 16),
                        _SectionHeader(
                          icon: Icons.price_change,
                          title: isRtl
                              ? 'مقارنة الأسعار عبر المتاجر'
                              : 'Price comparison across stores',
                          isRtl: isRtl,
                        ),
                        const SizedBox(height: 6),
                        if (_data!.priceComparison.isEmpty)
                          _EmptyHint(
                            isRtl: isRtl,
                            text: isRtl
                                ? 'أضف نفس المنتج في متاجر متعددة لمقارنة الأسعار'
                                : 'Add the same item at multiple stores to compare prices',
                          )
                        else
                          ..._data!.priceComparison.entries.map(
                            (e) => _PriceCompareRow(
                              itemName: e.key,
                              prices: e.value,
                              isRtl: isRtl,
                            ),
                          ),
                      ],
                    ),
            ),
    );
  }

  void _push(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}

// ────────────────────────── Data model ──────────────────────────────────

class _Analytics {
  final int totalLists;
  final int totalItems;
  final int totalStores;
  final int totalItemStoreLinks;
  final double itemsTotalValue;
  final List<ShoppingList> recentLists;
  final Map<int, int> itemsPerList;
  final Map<int, double> totalPerList;
  final Map<String, int> storeItemCounts;
  final int maxStoreCount;
  final List<Item> mostExpensive;
  final Map<String, List<(String, double?)>> priceComparison;

  const _Analytics({
    required this.totalLists,
    required this.totalItems,
    required this.totalStores,
    required this.totalItemStoreLinks,
    required this.itemsTotalValue,
    required this.recentLists,
    required this.itemsPerList,
    required this.totalPerList,
    required this.storeItemCounts,
    required this.maxStoreCount,
    required this.mostExpensive,
    required this.priceComparison,
  });

  bool get isEmpty => totalLists == 0 && totalItems == 0 && totalStores == 0;

  static Future<_Analytics> load() async {
    final lists = await ShoppingListDao.instance.all();
    final items = await ItemDao.instance.all();
    final stores = await StoreDao.instance.all();

    final itemsPerList = <int, int>{};
    final totalPerList = <int, double>{};
    for (final l in lists) {
      if (l.id == null) continue;
      final rows = await ListItemDao.instance.forListWithItems(l.id!);
      itemsPerList[l.id!] = rows.length;
      var sum = 0.0;
      for (final (item, li) in rows) {
        sum += (item.price ?? 0) * li.quantity;
      }
      totalPerList[l.id!] = sum;
    }

    // Stores by # of items tracked (via item_store).
    final storeItemCounts = <String, int>{};
    final itemStoreByItem = <int, List<ItemStore>>{};
    for (final it in items) {
      if (it.id == null) continue;
      final links = await ItemStoreDao.instance.forItem(it.id!);
      if (links.isNotEmpty) {
        itemStoreByItem[it.id!] = links;
        for (final link in links) {
          final store = stores.firstWhere(
            (s) => s.id == link.storeId,
            orElse: () => Store(name: '?', createdAt: DateTime.now()),
          );
          final name = store.name;
          storeItemCounts[name] = (storeItemCounts[name] ?? 0) + 1;
        }
      }
    }

    final maxStoreCount =
        storeItemCounts.values.fold<int>(0, (a, b) => a > b ? a : b);

    // Most expensive items (by stored price).
    final withPrice = items.where((i) => i.price != null).toList()
      ..sort((a, b) => (b.price ?? 0).compareTo(a.price ?? 0));
    final mostExpensive = withPrice.take(5).toList();

    // Price comparison: items with prices at 2+ stores.
    final priceComparison = <String, List<(String, double?)>>{};
    for (final it in items) {
      if (it.id == null) continue;
      final links = itemStoreByItem[it.id!] ?? const <ItemStore>[];
      if (links.length < 2) continue;
      final name = it.nameEn.isEmpty ? (it.nameAr ?? '') : it.nameEn;
      final entries = <(String, double?)>[];
      for (final link in links) {
        final store = stores.firstWhere(
          (s) => s.id == link.storeId,
          orElse: () => Store(name: '?', createdAt: DateTime.now()),
        );
        entries.add((store.name, link.price));
      }
      // Sort by price ascending (nulls last).
      entries.sort((a, b) {
        if (a.$2 == null) return 1;
        if (b.$2 == null) return -1;
        return a.$2!.compareTo(b.$2!);
      });
      priceComparison[name] = entries;
    }

    // Items total value (sum of all item prices — useful as a catalog KPI).
    final itemsTotalValue = items.fold<double>(
      0,
      (s, i) => s + (i.price ?? 0),
    );

    return _Analytics(
      totalLists: lists.length,
      totalItems: items.length,
      totalStores: stores.length,
      totalItemStoreLinks: storeItemCounts.values.fold<int>(0, (a, b) => a + b),
      itemsTotalValue: itemsTotalValue,
      recentLists: lists.take(5).toList(),
      itemsPerList: itemsPerList,
      totalPerList: totalPerList,
      storeItemCounts: storeItemCounts,
      maxStoreCount: maxStoreCount == 0 ? 1 : maxStoreCount,
      mostExpensive: mostExpensive,
      priceComparison: priceComparison,
    );
  }
}

// ────────────────────────── Widgets ─────────────────────────────────────

class _GreetingCard extends StatelessWidget {
  final String username;
  final bool isRtl;
  final _Analytics data;

  const _GreetingCard({
    required this.username,
    required this.isRtl,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(Icons.shopping_basket_rounded,
                  color: Theme.of(context).colorScheme.primary,),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isRtl ? 'أهلاً $username' : 'Hello, $username',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text(
                    isRtl
                        ? 'إليك ملخص نشاطك في بازار'
                        : "Here's your Bazaar activity at a glance",
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  final _Analytics data;
  final bool isRtl;

  const _KpiGrid({required this.data, required this.isRtl});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _KpiCard(
            icon: Icons.checklist,
            label: isRtl ? 'القوائم' : 'Lists',
            value: '${data.totalLists}',
            color: Colors.indigo,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _KpiCard(
            icon: Icons.inventory_2,
            label: isRtl ? 'المنتجات' : 'Items',
            value: '${data.totalItems}',
            color: Colors.deepOrange,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _KpiCard(
            icon: Icons.storefront,
            label: isRtl ? 'المتاجر' : 'Stores',
            value: '${data.totalStores}',
            color: Colors.teal,
          ),
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _KpiCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isRtl;
  final VoidCallback? onSeeAll;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.isRtl,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        if (onSeeAll != null)
          TextButton(
            onPressed: onSeeAll,
            child: Text(isRtl ? 'عرض الكل' : 'See all'),
          ),
      ],
    );
  }
}

class _ListTileCard extends StatelessWidget {
  final ShoppingList list;
  final int itemCount;
  final double total;
  final bool isRtl;
  final String langCode;

  const _ListTileCard({
    required this.list,
    required this.itemCount,
    required this.total,
    required this.isRtl,
    required this.langCode,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(Icons.checklist,
              color: Theme.of(context).colorScheme.primary,),
        ),
        title: Text(list.displayName(langCode)),
        subtitle: Text(
          isRtl
              ? '$itemCount منتج • الإجمالي ${total.toStringAsFixed(2)}'
              : '$itemCount items • Total ${total.toStringAsFixed(2)}',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ListDetailScreen(list: list),
            ),
          );
        },
      ),
    );
  }
}

class _StoreBarRow extends StatelessWidget {
  final String storeName;
  final int count;
  final double share;
  final bool isRtl;

  const _StoreBarRow({
    required this.storeName,
    required this.count,
    required this.share,
    required this.isRtl,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              storeName,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: share.clamp(0.0, 1.0),
                minHeight: 12,
                backgroundColor:
                    Theme.of(context).dividerColor.withValues(alpha: 0.3),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 28,
            child: Text(
              '$count',
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemRankRow extends StatelessWidget {
  final int rank;
  final Item item;
  final bool isRtl;
  final String langCode;

  const _ItemRankRow({
    required this.rank,
    required this.item,
    required this.isRtl,
    required this.langCode,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: rank == 1
            ? Colors.amber
            : rank == 2
                ? Colors.grey
                : rank == 3
                    ? Colors.brown
                    : Theme.of(context).dividerColor.withValues(alpha: 0.5),
        child: Text(
          '$rank',
          style: TextStyle(
            color: rank <= 3 ? Colors.white : null,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(item.displayName(langCode)),
      subtitle: item.barcode == null ? null : Text(item.barcode!),
      trailing: CurrencyDisplay(
        amount: item.price,
        overrideCurrency: item.currency,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}

class _PriceCompareRow extends StatelessWidget {
  final String itemName;
  final List<(String, double?)> prices;
  final bool isRtl;

  const _PriceCompareRow({
    required this.itemName,
    required this.prices,
    required this.isRtl,
  });

  @override
  Widget build(BuildContext context) {
    final cheapest = prices
        .where((p) => p.$2 != null)
        .map((p) => p.$2!)
        .fold<double?>(null, (a, b) => a == null ? b : (a < b ? a : b));

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(itemName,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: prices.map((p) {
                final isCheapest = cheapest != null && p.$2 == cheapest;
                return Chip(
                  avatar: Icon(
                    isCheapest ? Icons.price_check : Icons.store,
                    size: 18,
                    color: isCheapest ? Colors.green : null,
                  ),
                  label: Text(
                    p.$2 == null
                        ? '${p.$1}: —'
                        : '${p.$1}: ${p.$2!.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: isCheapest ? Colors.green : null,
                      fontWeight:
                          isCheapest ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  backgroundColor:
                      isCheapest ? Colors.green.withValues(alpha: 0.1) : null,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final bool isRtl;
  final String text;

  const _EmptyHint({required this.isRtl, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }
}
