import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/app_dimens.dart';
import '../../core/design/components/app_image.dart';
import '../../core/design/components/empty_state.dart';
import '../../core/design/components/swipe_to_delete.dart';
import '../../core/providers/data_providers.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/settings_providers.dart';
import '../../core/models/models.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../core/router/app_router.dart';

/// Store list with swipe-to-delete and live item counts.
class StoresScreen extends ConsumerWidget {
  const StoresScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final stores = ref.watch(storesStreamProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.storesTitle)),
      body: stores.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (rows) {
          if (rows.isEmpty) {
            return EmptyState(
              icon: Icons.storefront_outlined,
              title: l.noStores,
              hint: l.noStoresHint,
              actionLabel: l.newStore,
              onAction: () => context.push('/stores/new'),
            );
          }
          return ListView.builder(
            padding: AppDimens.pagePadding.copyWith(bottom: 96),
            itemCount: rows.length,
            itemBuilder: (context, i) {
              final store = rows[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: AppDimens.space2),
                child: SwipeToDelete(
                  confirmTitle: l.deleteStoreTitle,
                  confirmMessage: l.deleteStoreMessage(
                    store.displayName(
                      ref.read(localeProvider.notifier).effectiveCode,
                    ),
                  ),
                  onConfirmed: () async {
                    await ref
                        .read(databaseProvider)
                        .storeDao
                        .deleteStore(store.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(l.storeDeleted)));
                    }
                  },
                  child: Card(
                    child: ListTile(
                      onTap: () => context.push(Routes.store(store.id)),
                      leading: AppImage(
                        url: store.imageUrl,
                        size: AppDimens.storeAvatar,
                        fallbackIcon: Icons.storefront_outlined,
                      ),
                      title: Text(
                        store.displayName(
                          ref.read(localeProvider.notifier).effectiveCode,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle:
                          (store.website != null && store.website!.isNotEmpty)
                          ? Text(
                              store.website!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            )
                          : null,
                      trailing: const Icon(Icons.chevron_right, size: 20),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'stores-fab',
        onPressed: () => context.push('/stores/new'),
        icon: const Icon(Icons.add),
        label: Text(l.newStore),
      ),
    );
  }
}
