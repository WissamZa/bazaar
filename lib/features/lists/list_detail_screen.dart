import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/currencies.dart';
import '../../core/design/app_dimens.dart';
import '../../core/design/components/empty_state.dart';
import '../../core/design/components/price_text.dart';
import '../../core/providers/data_providers.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/settings_providers.dart';
import '../../core/models/models.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../core/router/app_router.dart';
import 'widgets/add_items_sheet.dart';
import 'widgets/list_item_row_tile.dart';

/// Shopping mode for one list: progress header, streamed rows, add-items
/// sheet and barcode scanning. The v1 version of this screen was a single
/// 1007-line file — v2 decomposes it into small widgets.
class ListDetailScreen extends ConsumerWidget {
  final int listId;

  const ListDetailScreen({super.key, required this.listId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final currency = ref.watch(currencyProvider);
    final header = ref.watch(listHeaderProvider(listId));
    final rows = ref.watch(listDetailProvider(listId));
    final locale = ref.watch(
      localeProvider.select((s) => s?.languageCode ?? 'en'),
    );

    final entry = header.value;
    final itemCount = entry?.itemCount ?? 0;
    final checked = entry?.checkedCount ?? 0;
    final totalAll = entry?.totalSar ?? 0;
    final totalChecked = entry?.checkedTotalSar ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          entry?.list.displayName(locale) ?? l.commonLoading,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: l.editList,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push(Routes.editList(listId)),
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'export') {
                final list = entry?.list;
                if (list != null) {
                  await ref
                      .read(shareServiceProvider)
                      .exportList(ShoppingList.fromRow(list));
                }
              } else if (v == 'delete') {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(l.deleteListTitle),
                    content: Text(l.deleteListMessage(entry?.list.name ?? '')),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Text(l.commonCancel),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: Text(l.commonDelete),
                      ),
                    ],
                  ),
                );
                if (ok == true && context.mounted) {
                  await ref
                      .read(databaseProvider)
                      .shoppingListDao
                      .deleteList(listId);
                  if (context.mounted) context.go(Routes.lists);
                }
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'export', child: Text(l.exportList)),
              PopupMenuItem(value: 'delete', child: Text(l.commonDelete)),
            ],
          ),
        ],
      ),
      body: rows.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (data) {
          if (data.isEmpty) {
            return EmptyState(
              icon: Icons.shopping_cart_outlined,
              title: l.listEmptyTitle,
              hint: l.listEmptyHint,
              actionLabel: l.addFromCatalog,
              onAction: () => _addItems(context, ref),
            );
          }
          return Column(
            children: [
              // ── Progress header ──────────────────────────────────────
              Card(
                margin: const EdgeInsets.fromLTRB(
                  AppDimens.space4,
                  4,
                  AppDimens.space4,
                  0,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppDimens.space4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              l.checkedCount(checked, itemCount),
                              style: theme.textTheme.titleSmall,
                            ),
                          ),
                          Text(
                            l.checkedTotal,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 6),
                          PriceText(
                            totalChecked / currency.toSarRate,
                            currency: currency,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDimens.space2),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppDimens.radiusS),
                        child: LinearProgressIndicator(
                          value: itemCount == 0 ? 0 : checked / itemCount,
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: AppDimens.space3),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            l.commonTotal,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          PriceText(
                            totalAll / currency.toSarRate,
                            currency: currency,
                            style: theme.textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // ── Rows ─────────────────────────────────────────────────
              Expanded(
                child: ListView.builder(
                  padding: AppDimens.pagePadding.copyWith(bottom: 96),
                  itemCount: data.length,
                  itemBuilder: (context, i) =>
                      ListItemRowTile(row: data[i], listId: listId),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'list-detail-fab',
        onPressed: () => _addItems(context, ref),
        icon: const Icon(Icons.add),
        label: Text(l.addFromCatalog),
      ),
    );
  }

  Future<void> _addItems(BuildContext context, WidgetRef ref) async {
    await AddItemsSheet.show(context, listId);
  }
}
