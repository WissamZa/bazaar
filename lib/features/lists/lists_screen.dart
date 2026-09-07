import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/currencies.dart';
import '../../core/design/app_dimens.dart';
import '../../core/design/components/empty_state.dart';
import '../../core/design/components/price_text.dart';
import '../../core/design/components/swipe_to_delete.dart';
import '../../core/providers/data_providers.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/settings_providers.dart';
import '../../core/models/models.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../core/router/app_router.dart';

/// Shopping lists overview with live stats (item counts + totals stream
/// from one aggregated SQL query).
class ListsScreen extends ConsumerWidget {
  const ListsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final lists = ref.watch(listsWithStatsProvider);
    final currency = ref.watch(currencyProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.listsTitle)),
      body: lists.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (rows) {
          if (rows.isEmpty) {
            return EmptyState(
              icon: Icons.list_alt_rounded,
              title: l.noLists,
              hint: l.noListsHint,
              actionLabel: l.newList,
              onAction: () => context.push('/lists/new'),
            );
          }
          return ListView.builder(
            padding: AppDimens.pagePadding.copyWith(bottom: 96),
            itemCount: rows.length,
            itemBuilder: (context, i) {
              final entry = rows[i];
              final done = entry.checkedCount;
              final total = entry.itemCount;
              return Padding(
                padding: const EdgeInsets.only(bottom: AppDimens.space2),
                child: SwipeToDelete(
                  confirmTitle: l.deleteListTitle,
                  confirmMessage: l.deleteListMessage(
                    entry.list.displayName(
                      ref.read(localeProvider.notifier).effectiveCode,
                    ),
                  ),
                  onConfirmed: () => ref
                      .read(databaseProvider)
                      .shoppingListDao
                      .deleteList(entry.list.id),
                  child: Card(
                    child: ListTile(
                      onTap: () => context.push(Routes.list(entry.list.id)),
                      leading: Container(
                        width: AppDimens.storeAvatar,
                        height: AppDimens.storeAvatar,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: total > 0 && done == total
                              ? Theme.of(context).colorScheme.secondaryContainer
                              : Theme.of(context).colorScheme.primaryContainer
                                    .withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(
                            AppDimens.radiusM,
                          ),
                        ),
                        child: Icon(
                          total > 0 && done == total
                              ? Icons.check_circle_outline
                              : Icons.shopping_cart_outlined,
                          color: total > 0 && done == total
                              ? Theme.of(context).colorScheme.secondary
                              : Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      title: Text(
                        entry.list.displayName(
                          ref.read(localeProvider.notifier).effectiveCode,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.checkedCount(done, total)),
                          if (total > 0) ...[
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(
                                AppDimens.radiusS,
                              ),
                              child: LinearProgressIndicator(
                                value: done / total,
                                minHeight: 4,
                              ),
                            ),
                          ],
                        ],
                      ),
                      trailing: PriceText(
                        entry.totalSar / currency.toSarRate,
                        currency: currency,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
