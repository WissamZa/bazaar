import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/currencies.dart';
import '../../core/database/app_database.dart' show StoreRow;
import '../../core/design/app_dimens.dart';
import '../../core/design/components/app_image.dart';
import '../../core/design/components/empty_state.dart';
import '../../core/design/components/price_text.dart';
import '../../core/design/components/section_header.dart';
import '../../core/providers/data_providers.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/settings_providers.dart';
import '../../core/models/models.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../core/router/app_router.dart';

final _storeFamily = StreamProvider.family<StoreRow?, int>((ref, id) {
  return ref.watch(databaseProvider).storeDao.watchById(id);
});

/// Items and their recorded prices at one store — one streamed JOIN.
class StoreDetailScreen extends ConsumerWidget {
  final int storeId;

  const StoreDetailScreen({super.key, required this.storeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final currency = ref.watch(currencyProvider);
    final locale = ref.watch(
      localeProvider.select((s) => s?.languageCode ?? 'en'),
    );
    final store = ref.watch(_storeFamily(storeId)).value;
    final items = ref.watch(storeDetailProvider(storeId));

    return Scaffold(
      appBar: AppBar(
        title: Text(store?.displayName(locale) ?? l.storesTitle),
        actions: [
          IconButton(
            tooltip: l.editStore,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push(Routes.editStore(storeId)),
          ),
        ],
      ),
      body: items.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (rows) {
          if (rows.isEmpty) {
            return EmptyState(
              icon: Icons.inventory_2_outlined,
              title: l.noItemsAtStore,
              hint: l.homeNoItemsHint,
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(l.itemsAtStore),
              Expanded(
                child: ListView.builder(
                  padding: AppDimens.pagePadding.copyWith(bottom: 24),
                  itemCount: rows.length,
                  itemBuilder: (context, i) {
                    final r = rows[i];
                    return Card(
                      child: ListTile(
                        onTap: () => context.push(Routes.item(r.item.id)),
                        leading: AppImage(url: r.item.imageUrl),
                        title: Text(
                          r.item.displayName(locale),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle:
                            r.item.brand != null && r.item.brand!.isNotEmpty
                            ? Text(r.item.brand!)
                            : null,
                        trailing: PriceText(
                          r.price.price != null
                              ? currencyFromCode(
                                  r.price.currency,
                                ).convertTo(r.price.price!, currency)
                              : null,
                          currency: currency,
                          showZero: false,
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
