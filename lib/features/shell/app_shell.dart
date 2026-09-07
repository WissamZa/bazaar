import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../core/router/app_router.dart';

/// The 4-tab bottom navigation shell (Home / Items / Lists / Stores).
class AppShell extends ConsumerWidget {
  final StatefulNavigationShell shell;

  const AppShell({super.key, required this.shell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      body: shell,
      floatingActionButton: _fabFor(context, shell.currentIndex),
      floatingActionButtonLocation: FloatingActionButtonLocation.endContained,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) =>
            shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home_rounded),
            label: l.tabHome,
          ),
          NavigationDestination(
            icon: const Icon(Icons.inventory_2_outlined),
            selectedIcon: const Icon(Icons.inventory_2_rounded),
            label: l.tabItems,
          ),
          NavigationDestination(
            icon: const Icon(Icons.list_alt_outlined),
            selectedIcon: const Icon(Icons.list_alt_rounded),
            label: l.tabLists,
          ),
          NavigationDestination(
            icon: const Icon(Icons.storefront_outlined),
            selectedIcon: const Icon(Icons.storefront_rounded),
            label: l.tabStores,
          ),
        ],
      ),
    );
  }

  Widget? _fabFor(BuildContext context, int index) {
    switch (index) {
      case 0:
        return null;
      case 1:
        return FloatingActionButton.extended(
          heroTag: 'fab-items',
          onPressed: () => context.push(Routes.newItem()),
          icon: const Icon(Icons.add),
          label: Text(AppLocalizations.of(context)!.addItem),
        );
      case 2:
        return FloatingActionButton.extended(
          heroTag: 'fab-lists',
          onPressed: () => context.push('/lists/new'),
          icon: const Icon(Icons.add),
          label: Text(AppLocalizations.of(context)!.newList),
        );
      default:
        return FloatingActionButton.extended(
          heroTag: 'fab-stores',
          onPressed: () => context.push('/stores/new'),
          icon: const Icon(Icons.add),
          label: Text(AppLocalizations.of(context)!.newStore),
        );
    }
  }
}
