import 'package:flutter/material.dart';
import '../../../core/models/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/currencies.dart';
import '../../../core/design/app_dimens.dart';
import '../../../core/design/components/app_image.dart';
import '../../../core/design/components/price_text.dart';
import '../../../core/design/components/quantity_stepper.dart';
import '../../../core/design/components/section_header.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/database/daos/list_item_dao.dart' show ListItemWithItem;
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/settings_providers.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../core/router/app_router.dart';

/// One shopping-list row: checkbox, item info, quantity stepper, effective
/// price, and a per-row bottom sheet (preferred store / remove).
class ListItemRowTile extends ConsumerWidget {
  final ListItemWithItem row;
  final int listId;

  const ListItemRowTile({super.key, required this.row, required this.listId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;
    final currency = ref.watch(currencyProvider);
    final locale = ref.watch(
      localeProvider.select((s) => s?.languageCode ?? 'en'),
    );
    final li = row.listItem;
    final item = row.item;
    final checked = li.isChecked == 1;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppDimens.space4,
        vertical: 2,
      ),
      leading: Checkbox(
        value: checked,
        onChanged: (v) async {
          await ref
              .read(databaseProvider)
              .listItemDao
              .setChecked(li.id, v == true);
          await ref.read(databaseProvider).shoppingListDao.touch(listId);
        },
      ),
      onTap: () => _openRowMenu(context, ref),
      title: Text(
        item.displayName(locale),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyLarge?.copyWith(
          decoration: checked ? TextDecoration.lineThrough : null,
          color: checked ? theme.colorScheme.onSurfaceVariant : null,
        ),
      ),
      subtitle: Row(
        children: [
          QuantityStepper(
            value: li.quantity,
            onChanged: (v) async {
              await ref
                  .read(databaseProvider)
                  .listItemDao
                  .setQuantity(li.id, v);
              await ref.read(databaseProvider).shoppingListDao.touch(listId);
            },
          ),
          const SizedBox(width: AppDimens.space2),
          Flexible(
            child: Text(
              _storeLabel(l),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
      trailing: PriceText(
        row.effectivePrice != null
            ? currencyFromCode(
                row.effectiveCurrency,
              ).convertTo(row.effectivePrice!, currency)
            : null,
        currency: currency,
        showZero: false,
        style: theme.textTheme.titleSmall?.copyWith(
          color: checked ? theme.colorScheme.onSurfaceVariant : null,
        ),
      ),
    );
  }

  String _storeLabel(AppLocalizations l) {
    final storeName = row.preferredStore?.name;
    if (row.listItem.preferredStoreId != null && storeName != null) {
      return storeName;
    }
    if (row.lowestPrice != null) {
      return l.noPreferredStore;
    }
    return '';
  }

  Future<void> _openRowMenu(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context)!;
    final db = ref.read(databaseProvider);
    final stores = await db.storeDao.all();

    if (!context.mounted) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.storefront_outlined),
              title: Text(l.changeStore),
              subtitle: Text(_storeLabel(l)),
              onTap: () => Navigator.of(context).pop('store'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(l.editItem),
              onTap: () => Navigator.of(context).pop('edit'),
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(l.removeFromList),
              onTap: () => Navigator.of(context).pop('remove'),
            ),
          ],
        ),
      ),
    );

    switch (action) {
      case 'edit':
        if (context.mounted) context.push(Routes.item(row.item.id));
      case 'remove':
        await db.listItemDao.removeRow(row.listItem.id);
        await db.shoppingListDao.touch(listId);
      case 'store':
        if (!context.mounted) return;
        final selected = await showModalBottomSheet<int>(
          context: context,
          showDragHandle: true,
          builder: (context) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  leading: const Icon(Icons.auto_awesome_outlined),
                  title: Text(l.noPreferredStore),
                  onTap: () => Navigator.of(context).pop(0),
                ),
                for (final s in stores)
                  ListTile(
                    leading: const Icon(Icons.storefront_outlined),
                    title: Text(s.name),
                    subtitle: (s.nameAr != null && s.nameAr!.isNotEmpty)
                        ? Text(s.nameAr!)
                        : null,
                    onTap: () => Navigator.of(context).pop(s.id),
                  ),
              ],
            ),
          ),
        );
        if (selected != null) {
          await db.listItemDao.setPreferredStore(
            row.listItem.id,
            selected == 0 ? null : selected,
          );
          await db.shoppingListDao.touch(listId);
        }
    }
  }
}
