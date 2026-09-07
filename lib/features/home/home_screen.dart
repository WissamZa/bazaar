import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/app_dimens.dart';
import '../../core/design/components/app_image.dart';
import '../../core/design/components/kpi_card.dart';
import '../../core/design/components/price_text.dart';
import '../../core/design/components/section_header.dart';
import '../../core/design/components/empty_state.dart';
import '../../core/providers/data_providers.dart';
import '../../core/providers/settings_providers.dart';
import '../../core/constants/currencies.dart';
import '../../core/models/models.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../core/router/app_router.dart';

/// Dashboard: greeting, KPI grid, recent lists, stores by item count, and
/// the most expensive items. Every section streams live from the database.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final username = ref.watch(userProvider);
    final currency = ref.watch(currencyProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_greeting(l, username)),
        actions: [
          IconButton(
            tooltip: l.settingsTitle,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(Routes.settings),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppDimens.space6),
        children: [
          // ── KPI grid ────────────────────────────────────────────────────
          Padding(
            padding: AppDimens.pagePadding,
            child: Row(
              children: [
                Expanded(
                  child: _kpi(
                    ref,
                    context,
                    icon: Icons.list_alt_rounded,
                    provider: listsCountProvider,
                    label: l.homeKpiLists,
                    accent: theme.colorScheme.primary,
                    onTap: () => context.go(Routes.lists),
                  ),
                ),
                const SizedBox(width: AppDimens.space3),
                Expanded(
                  child: _kpi(
                    ref,
                    context,
                    icon: Icons.inventory_2_rounded,
                    provider: itemsCountProvider,
                    label: l.homeKpiItems,
                    accent: theme.colorScheme.tertiary,
                    onTap: () => context.go(Routes.items),
                  ),
                ),
                const SizedBox(width: AppDimens.space3),
                Expanded(
                  child: _kpi(
                    ref,
                    context,
                    icon: Icons.storefront_rounded,
                    provider: storesCountProvider,
                    label: l.homeKpiStores,
                    accent: theme.colorScheme.secondary,
                    onTap: () => context.go(Routes.stores),
                  ),
                ),
              ],
            ),
          ),

          // ── Recent lists ────────────────────────────────────────────────
          SectionHeader(
            l.homeRecentLists,
            padding: const EdgeInsets.fromLTRB(
              AppDimens.space4,
              AppDimens.space5,
              0,
              8,
            ),
            trailing: TextButton(
              onPressed: () => context.go(Routes.lists),
              child: Text(l.commonViewAll),
            ),
          ),
          _RecentLists(currency: currency),

          // ── Stores by item count ────────────────────────────────────────
          SectionHeader(l.homeStoresByItems),
          const _StoresByItems(),

          // ── Most expensive items ────────────────────────────────────────
          SectionHeader(l.homeTopExpensive),
          const _TopExpensive(),
        ],
      ),
    );
  }

  Widget _kpi(
    WidgetRef ref,
    BuildContext context, {
    required IconData icon,
    required StreamProvider<int> provider,
    required String label,
    required Color accent,
    VoidCallback? onTap,
  }) {
    final value = ref.watch(provider).value ?? 0;
    return KpiCard(
      icon: icon,
      value: value,
      label: label,
      accent: accent,
      onTap: onTap,
    );
  }

  String _greeting(AppLocalizations l, String? username) {
    final hour = DateTime.now().hour;
    final base = hour < 12
        ? l.greetingMorning
        : hour < 17
        ? l.greetingAfternoon
        : hour < 22
        ? l.greetingEvening
        : l.greetingNight;
    return username == null || username.isEmpty ? base : '$base · $username';
  }
}

class _RecentLists extends ConsumerWidget {
  final AppCurrency currency;
  const _RecentLists({required this.currency});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final lists = ref.watch(recentListsProvider);

    return lists.when(
      loading: () => const LinearProgressIndicator(minHeight: 2),
      error: (_, __) => const SizedBox.shrink(),
      data: (data) {
        if (data.isEmpty) {
          return EmptyState(
            icon: Icons.list_alt_rounded,
            title: l.homeNoLists,
            hint: l.homeNoListsHint,
            actionLabel: l.homeCreateList,
            onAction: () => context.push('/lists/new'),
          );
        }
        return Padding(
          padding: AppDimens.pagePadding,
          child: Column(
            children: [
              for (final entry in data)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppDimens.space2),
                  child: Card(
                    child: ListTile(
                      onTap: () => context.push(Routes.list(entry.list.id)),
                      leading: Container(
                        width: AppDimens.storeAvatar,
                        height: AppDimens.storeAvatar,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withValues(
                            alpha: 0.6,
                          ),
                          borderRadius: BorderRadius.circular(
                            AppDimens.radiusM,
                          ),
                        ),
                        child: Icon(
                          Icons.shopping_cart_outlined,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      title: Text(
                        entry.list.displayName(
                          ref.read(localeProvider.notifier).effectiveCode,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(l.itemsCount(entry.itemCount)),
                      trailing: PriceText(
                        entry.totalSar / currency.toSarRate,
                        currency: currency,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _StoresByItems extends ConsumerWidget {
  const _StoresByItems();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final stores = ref.watch(storesByItemCountProvider);

    return stores.when(
      loading: () => const LinearProgressIndicator(minHeight: 2),
      error: (_, __) => const SizedBox.shrink(),
      data: (data) {
        if (data.isEmpty) {
          return EmptyState(
            icon: Icons.storefront_outlined,
            title: l.homeNoStores,
            hint: l.homeNoStoresHint,
          );
        }
        final max = data
            .map((e) => e.itemCount)
            .fold(1, (a, b) => a > b ? a : b);
        return Padding(
          padding: AppDimens.pagePadding,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(AppDimens.space4),
              child: Column(
                children: [
                  for (final entry in data)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppDimens.space3),
                      child: InkWell(
                        onTap: () => context.push(Routes.store(entry.store.id)),
                        borderRadius: BorderRadius.circular(AppDimens.radiusS),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    entry.store.displayName(
                                      ref
                                          .read(localeProvider.notifier)
                                          .effectiveCode,
                                    ),
                                    style: theme.textTheme.bodyMedium,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '${entry.itemCount}',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(
                                AppDimens.radiusS,
                              ),
                              child: LinearProgressIndicator(
                                value: entry.itemCount / max,
                                minHeight: 6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TopExpensive extends ConsumerWidget {
  const _TopExpensive();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final items = ref.watch(topExpensiveItemsProvider);
    final currency = ref.watch(currencyProvider);

    return items.when(
      loading: () => const LinearProgressIndicator(minHeight: 2),
      error: (_, __) => const SizedBox.shrink(),
      data: (data) {
        if (data.isEmpty) {
          return EmptyState(
            icon: Icons.inventory_2_outlined,
            title: l.homeNoItems,
            hint: l.homeNoItemsHint,
            actionLabel: l.homeScanFirst,
            onAction: () => context.push(Routes.scan()),
          );
        }
        final medals = [
          Icons.looks_one_rounded,
          Icons.looks_two_rounded,
          Icons.looks_3_rounded,
        ];
        return Padding(
          padding: AppDimens.pagePadding,
          child: Card(
            child: Column(
              children: [
                for (var i = 0; i < data.length; i++)
                  ListTile(
                    onTap: () => context.push(Routes.item(data[i].item.id)),
                    leading: i < 3
                        ? Icon(medals[i], color: theme.colorScheme.primary)
                        : Text(
                            '${i + 1}',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                    title: Text(
                      data[i].item.displayName(
                        ref.read(localeProvider.notifier).effectiveCode,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: data[i].item.brand != null
                        ? Text(
                            data[i].item.brand!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                        : null,
                    trailing: PriceText(
                      data[i].displayPrice != null
                          ? currencyFromCode(
                              data[i].effectiveCurrency,
                            ).convertTo(data[i].displayPrice!, currency)
                          : null,
                      currency: currency,
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
