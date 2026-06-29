import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/database/dao/list_item_dao.dart';
import '../../core/database/dao/shopping_list_dao.dart';
import '../../core/models/shopping_list.dart';
import '../../core/providers/locale_provider.dart';
import '../../core/providers/user_provider.dart';
import '../../widgets/empty_state.dart';
import 'add_edit_list_screen.dart';
import 'list_detail_screen.dart';

class ListsScreen extends StatefulWidget {
  const ListsScreen({super.key});

  @override
  State<ListsScreen> createState() => _ListsScreenState();
}

class _ListsScreenState extends State<ListsScreen> {
  List<ShoppingList> _lists = [];
  bool _loading = true;
  Map<int, int> _itemCounts = {};

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final user = context.read<UserProvider>().username ?? 'local';
      _lists = await ShoppingListDao.instance.all(owner: user);
      _itemCounts = {};
      for (final l in _lists) {
        final items = await ListItemDao.instance.forList(l.id!);
        _itemCounts[l.id!] = items.length;
      }
    } catch (e) {
      debugPrint('Error refreshing lists: $e');
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _openAddEdit({ShoppingList? list}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AddEditListScreen(list: list)),
    );
    _refresh();
  }

  Future<void> _openDetail(ShoppingList list) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ListDetailScreen(list: list)),
    );
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    return _loading
        ? const Center(child: CircularProgressIndicator())
        : _lists.isEmpty
            ? EmptyState(
                icon: Icons.checklist_outlined,
                title: locale.isRtl
                    ? 'لا توجد قوائم تسوق بعد'
                    : 'No shopping lists yet',
                hint: locale.isRtl
                    ? 'أنشئ قائمة لبدء التسوق'
                    : 'Create a list to start shopping',
                actionLabel: locale.isRtl ? 'قائمة جديدة' : 'New List',
                onAction: () => _openAddEdit(),
              )
            : RefreshIndicator(
                onRefresh: _refresh,
                child: ListView.builder(
                  itemCount: _lists.length,
                  itemBuilder: (_, i) {
                    final list = _lists[i];
                    final count = _itemCounts[list.id!] ?? 0;
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              Theme.of(context).colorScheme.primaryContainer,
                          child: Icon(
                            Icons.checklist,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                          ),
                        ),
                        title: Text(list
                            .displayName(locale.locale?.languageCode ?? 'en')),
                        subtitle: Text(
                          locale.isRtl
                              ? '$count عنصر · ${list.owner}'
                              : '$count items · ${list.owner}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _openDetail(list),
                      ),
                    );
                  },
                ),
              );
  }
}
