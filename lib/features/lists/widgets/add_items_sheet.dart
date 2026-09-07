import 'package:flutter/material.dart';
import '../../../core/models/models.dart';
import '../../../core/router/app_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_dimens.dart';
import '../../../core/design/components/app_image.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/settings_providers.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Multi-select picker over the item catalog, streamed live and filtered by
/// a search field. Adds checked items (with quantities) to the list.
class AddItemsSheet extends ConsumerStatefulWidget {
  final int listId;

  const AddItemsSheet({super.key, required this.listId});

  /// Opens the sheet; returns the number of rows added (0 when dismissed).
  static Future<int> show(BuildContext context, int listId) async {
    final result = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => AddItemsSheet(listId: listId),
    );
    return result ?? 0;
  }

  @override
  ConsumerState<AddItemsSheet> createState() => _AddItemsSheetState();
}

class _AddItemsSheetState extends ConsumerState<AddItemsSheet> {
  final _selected = <int, int>{}; // itemId → quantity
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final items = ref.watch(itemsStreamProvider);
    final locale = ref.watch(
      localeProvider.select((s) => s?.languageCode ?? 'en'),
    );

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.space5),
            child: TextField(
              autofocus: false,
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: l.searchItemsToAdd,
                prefixIcon: const Icon(Icons.search),
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: items.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (rows) {
                final q = _search.trim().toLowerCase();
                final filtered = q.isEmpty
                    ? rows
                    : rows
                          .where(
                            (r) =>
                                r.item.nameEn.toLowerCase().contains(q) ||
                                (r.item.nameAr ?? '').contains(q),
                          )
                          .toList();
                if (filtered.isEmpty) {
                  return Center(child: Text(l.noItemsToAdd));
                }
                return ListView.builder(
                  controller: scrollController,
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final row = filtered[i];
                    final selected = _selected.containsKey(row.item.id);
                    return CheckboxListTile(
                      value: selected,
                      onChanged: (_) => setState(() {
                        if (selected) {
                          _selected.remove(row.item.id);
                        } else {
                          _selected[row.item.id] = 1;
                        }
                      }),
                      secondary: AppImage(
                        url: row.item.imageUrl,
                        size: AppDimens.listItemImage - 8,
                      ),
                      title: Text(
                        row.item.displayName(locale),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppDimens.space4),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.push(Routes.newItem()),
                      icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                      label: Text(l.scanNewItem),
                    ),
                  ),
                  const SizedBox(width: AppDimens.space3),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: _selected.isEmpty
                          ? null
                          : () async {
                              final db = ref.read(databaseProvider);
                              for (final entry in _selected.entries) {
                                await db.listItemDao.addItemToList(
                                  listId: widget.listId,
                                  itemId: entry.key,
                                  quantity: entry.value,
                                );
                              }
                              await db.shoppingListDao.touch(widget.listId);
                              if (context.mounted) {
                                Navigator.of(context).pop(_selected.length);
                              }
                            },
                      icon: const Icon(Icons.add),
                      label: Text(l.addFromCatalog),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (theme.brightness == Brightness.dark) const SizedBox(height: 4),
        ],
      ),
    );
  }
}
