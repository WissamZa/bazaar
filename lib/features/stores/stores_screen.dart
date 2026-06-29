import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/database/dao/store_dao.dart';
import '../../core/models/store.dart';
import '../../core/providers/locale_provider.dart';
import '../../widgets/empty_state.dart';
import 'add_edit_store_screen.dart';
import 'store_detail_screen.dart';

class StoresScreen extends StatefulWidget {
  const StoresScreen({super.key});

  @override
  State<StoresScreen> createState() => _StoresScreenState();
}

class _StoresScreenState extends State<StoresScreen> {
  List<Store> _stores = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    _stores = await StoreDao.instance.all();
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _openAddEdit({Store? store}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AddEditStoreScreen(store: store)),
    );
    _refresh();
  }

  /// Show address (preferred) or website as the subtitle. If both are empty
  /// returns null so the ListTile collapses to a single line.
  Widget? _storeSubtitle(Store store, bool isRtl) {
    final parts = <String>[];
    if ((store.address ?? '').isNotEmpty) parts.add(store.address!);
    if ((store.website ?? '').isNotEmpty) parts.add(store.website!);
    if (parts.isEmpty) return null;
    return Text(
      parts.join(' · '),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _stores.isEmpty
              ? EmptyState(
                  icon: Icons.storefront_outlined,
                  title: locale.isRtl ? 'لا توجد متاجر بعد' : 'No stores yet',
                  hint: locale.isRtl
                      ? 'أضف متجراً لتتبع الأسعار'
                      : 'Add a store to track prices',
                  actionLabel: locale.isRtl ? 'متجر جديد' : 'New Store',
                  onAction: () => _openAddEdit(),
                )
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.builder(
                    itemCount: _stores.length,
                    itemBuilder: (_, i) {
                      final store = _stores[i];
                      return Dismissible(
                        key: ValueKey(store.id ?? i),
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 24),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        direction: DismissDirection.endToStart,
                        confirmDismiss: (_) async {
                          return await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: Text(
                                    locale.isRtl
                                        ? 'تأكيد الحذف؟'
                                        : 'Confirm delete?',
                                  ),
                                  content: Text(
                                    locale.isRtl
                                        ? 'لا يمكن التراجع عن هذا الإجراء.'
                                        : 'This action cannot be undone.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: Text(
                                        locale.isRtl ? 'إلغاء' : 'Cancel',
                                      ),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child:
                                          Text(locale.isRtl ? 'حذف' : 'Delete'),
                                    ),
                                  ],
                                ),
                              ) ??
                              false;
                        },
                        onDismissed: (_) async {
                          await StoreDao.instance.delete(store.id!);
                          _stores.removeAt(i);
                          setState(() {});
                        },
                        child: Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer,
                              child: Icon(
                                Icons.storefront,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer,
                              ),
                            ),
                            title: Text(
                              store.displayName(
                                locale.locale?.languageCode ?? 'en',
                              ),
                            ),
                            subtitle: _storeSubtitle(store, locale.isRtl),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => StoreDetailScreen(store: store),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddEdit(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
