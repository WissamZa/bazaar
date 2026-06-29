import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/providers/locale_provider.dart';
import 'home/home_screen.dart';
import 'items/items_screen.dart';
import 'settings/settings_screen.dart';
import 'shopping_lists/lists_screen.dart';
import 'stores/stores_screen.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/language_toggle.dart';
import '../widgets/theme_toggle.dart';

/// Scaffold holding the four tab screens + settings entry in the app bar.
/// Tab order: Home (analytics) | Items | Lists | Stores.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  final _screens = const [
    HomeScreen(),
    ItemsScreen(),
    ListsScreen(),
    StoresScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final titles = locale.isRtl
        ? ['الرئيسية', 'المنتجات', 'قوائم التسوق', 'المتاجر']
        : ['Home', 'Items', 'Shopping Lists', 'Stores'];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.shopping_basket_rounded,
                color: Theme.of(context).colorScheme.primary,),
            const SizedBox(width: 8),
            Text(titles[_index]),
          ],
        ),
        actions: [
          const LanguageToggle(),
          const ThemeToggle(),
          IconButton(
            tooltip: locale.isRtl ? 'الإعدادات' : 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: _screens,
      ),
      bottomNavigationBar: BottomNav(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}
