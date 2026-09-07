import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/currencies.dart';
import '../../core/database/daos/item_dao.dart';
import '../../core/database/app_database.dart' show ItemRow;
import '../../core/design/app_dimens.dart';
import '../../core/design/components/app_image.dart';
import '../../core/design/components/empty_state.dart';
import '../../core/design/components/price_text.dart';
import '../../core/design/components/swipe_to_delete.dart';
import '../../core/providers/data_providers.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/settings_providers.dart';
import '../../core/models/models.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../core/router/app_router.dart';

/// Searchable, sortable item catalog with effective prices. Deletes and
/// edits act on the database; the UI updates via the stream.
class ItemsScreen extends ConsumerStatefulWidget {
  const ItemsScreen({super.key});

  @override
  ConsumerState<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends ConsumerState<ItemsScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final currency = ref.watch(currencyProvider);
    final items = ref.watch(itemsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.itemsTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: l.sortAndGroup,
            onPressed: () => _openSortSheet(context),
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            tooltip: l.scanBarcode,
            onPressed: () => context.push(Routes.scan()),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.space4,
              0,
              AppDimens.space4,
              AppDimens.space2,
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => ref.read(itemSearchProvider.notifier).state = v,
              decoration: InputDecoration(
                hintText: l.searchItems,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: ListenableBuilder(
                  listenable: _searchController,
                  builder: (context, _) => _searchController.text.isEmpty
                      ? const SizedBox.shrink()
                      : IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            ref.read(itemSearchProvider.notifier).state = '';
                          },
                        ),
                ),
              ),
            ),
          ),
          Expanded(
            child: items.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('${l.commonError}: $e')),
              data: (rows) {
                if (rows.isEmpty) {
                  return EmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: ref.read(itemSearchProvider).isEmpty
                        ? l.noItems
                        : l.noItemsToAdd,
                    hint: ref.read(itemSearchProvider).isEmpty
                        ? l.noItemsHint
                        : null,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {},
                  child: ListView.builder(
                    padding: AppDimens.pagePadding.copyWith(bottom: 96),
                    itemCount: rows.length,
                    itemBuilder: (context, i) {
                      final row = rows[i];
                      return _ItemCard(
                        row: row,
                        currency: currency,
                        locale: ref.read(localeProvider.notifier).effectiveCode,
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'items-fab',
        onPressed: () => context.push(Routes.newItem()),
        icon: const Icon(Icons.add),
        label: Text(l.addItem),
      ),
    );
  }

  void _openSortSheet(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppDimens.space5),
              child: Text(l.sortBy, style: theme.textTheme.titleMedium),
            ),
            const SizedBox(height: AppDimens.space2),
            for (final sort in ItemSort.values)
              RadioListTile<ItemSort>(
                title: Text(switch (sort) {
                  ItemSort.newest => l.sortNewest,
                  ItemSort.name => l.sortName,
                  ItemSort.priceHigh => l.sortPriceHigh,
                  ItemSort.priceLow => l.sortPriceLow,
                }),
                value: sort,
                groupValue: ref.read(itemSortProvider),
                onChanged: (v) {
                  ref.read(itemSortProvider.notifier).set(v!);
                  Navigator.of(context).pop();
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _ItemCard extends ConsumerWidget {
  final ItemWithEffectivePrice row;
  final AppCurrency currency;
  final String locale;

  const _ItemCard({
    required this.row,
    required this.currency,
    required this.locale,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;
    final item = row.item;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.space2),
      child: SwipeToDelete(
        confirmTitle: l.deleteItemTitle,
        confirmMessage: l.deleteItemMessage(item.displayName(locale)),
        onConfirmed: () async {
          await ref.read(databaseProvider).itemDao.deleteItem(item.id);
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(l.itemDeleted)));
          }
        },
        child: Card(
          child: ListTile(
            onTap: () => context.push(Routes.item(item.id)),
            leading: AppImage(url: item.imageUrl),
            title: Text(
              item.displayName(locale),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Row(
              children: [
                if (item.brand != null && item.brand!.isNotEmpty)
                  Flexible(
                    child: Text(
                      item.brand!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                if (item.barcode != null) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      item.barcode!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'AppMono',
                        fontSize: 10.5,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            trailing: PriceText(
              row.displayPrice != null
                  ? currencyFromCode(
                      row.effectiveCurrency,
                    ).convertTo(row.displayPrice!, currency)
                  : null,
              currency: currency,
              style: theme.textTheme.titleSmall,
            ),
          ),
        ),
      ),
    );
  }
}
