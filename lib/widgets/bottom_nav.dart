import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/providers/locale_provider.dart';

/// Bottom navigation bar with three tabs: Items | Lists | Stores.
/// Labels switch automatically between EN and AR.
class BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const BottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final isAr = locale.isRtl;

    final labels = isAr
        ? const ['المنتجات', 'قوائم التسوق', 'المتاجر']
        : const ['Items', 'Lists', 'Stores'];

    final items = <BottomNavigationBarItem>[
      BottomNavigationBarItem(
        icon: const Icon(Icons.inventory_2_outlined),
        activeIcon: const Icon(Icons.inventory_2),
        label: labels[0],
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.checklist_outlined),
        activeIcon: const Icon(Icons.checklist),
        label: labels[1],
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.storefront_outlined),
        activeIcon: const Icon(Icons.storefront),
        label: labels[2],
      ),
    ];

    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      items: items,
      selectedItemColor: Theme.of(context).colorScheme.primary,
      unselectedItemColor: Theme.of(context).colorScheme.onSurfaceVariant,
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
    );
  }
}
