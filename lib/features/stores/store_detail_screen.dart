import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/database/dao/item_dao.dart';
import '../../core/database/dao/item_store_dao.dart';
import '../../core/database/dao/store_dao.dart';
import '../../core/models/item.dart';
import '../../core/models/store.dart';
import '../../core/providers/locale_provider.dart';
import '../items/add_edit_item_screen.dart';
import 'add_edit_store_screen.dart';

class StoreDetailScreen extends StatefulWidget {
  final Store store;
  const StoreDetailScreen({super.key, required this.store});

  @override
  State<StoreDetailScreen> createState() => _StoreDetailScreenState();
}

class _StoreDetailScreenState extends State<StoreDetailScreen> {
  List<Item> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() => _loading = true);
    final relations = await ItemStoreDao.instance.forStore(widget.store.id!);
    final items = await Future.wait(
      relations.map((r) => ItemDao.instance.findById(r.itemId)),
    );
    setState(() {
      _items = items.whereType<Item>().toList();
      _loading = false;
    });
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
                        builder: (_) => AddEditStoreScreen(store: widget.store),
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
          : _items.isEmpty
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
              : ListView.builder(
                  itemCount: _items.length,
                  itemBuilder: (_, i) {
                    final item = _items[i];
                    return Card(
                      child: ListTile(
                        title: Text(item.displayName(langCode)),
                        subtitle: Text(item.price?.toStringAsFixed(2) ?? '—'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AddEditItemScreen(item: item),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
