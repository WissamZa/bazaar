import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/username_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/items/add_edit_item_screen.dart';
import '../../features/items/items_screen.dart';
import '../../features/lists/add_edit_list_screen.dart';
import '../../features/lists/list_detail_screen.dart';
import '../../features/lists/lists_screen.dart';
import '../../features/scanner/scan_result_screen.dart';
import '../../features/scanner/scanner_screen.dart';
import '../../features/settings/category_settings_screen.dart';
import '../../features/settings/llm_settings_screen.dart';
import '../../features/settings/pipeline_debugger_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/shell/app_shell.dart';
import '../../features/stores/add_edit_store_screen.dart';
import '../../features/stores/store_detail_screen.dart';
import '../../features/stores/stores_screen.dart';
import '../providers/settings_providers.dart';

/// Typed route paths.
abstract final class Routes {
  static const home = '/';
  static const items = '/items';
  static const lists = '/lists';
  static const stores = '/stores';
  static const username = '/username';
  static const settings = '/settings';
  static const categories = '/settings/categories';
  static const llmSettings = '/settings/search-ai';
  static const pipelineDebugger = '/settings/search-ai/debugger';

  static String item(int id) => '/items/$id';
  static String editItem(int id) => '/items/$id/edit';
  static String newItem({String? barcode}) =>
      '/items/new${barcode != null ? '?barcode=$barcode' : ''}';
  static String list(int id) => '/lists/$id';
  static String editList(int id) => '/lists/$id/edit';
  static String store(int id) => '/stores/$id';
  static String editStore(int id) => '/stores/$id/edit';
  static String scan({String? listId}) =>
      '/scan${listId != null ? '?list=$listId' : ''}';
  static String scanResult(String barcode, {String? listId}) =>
      '/scan/result?barcode=$barcode${listId != null ? '&list=$listId' : ''}';
}

final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Global app navigation. The four tabs live in a StatefulShellRoute so
/// each tab keeps its own navigation stack.
///
/// The [userProvider] drives a `refreshListenable`: completing onboarding
/// (or clearing the user) re-runs [GoRouter.redirect] and lands on the
/// right screen.
final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(userProvider, (_, __) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: ref.read(userProvider) != null
        ? Routes.home
        : Routes.username,
    refreshListenable: refresh,
    redirect: (context, state) {
      final loggedIn = ref.read(userProvider) != null;
      final onUsername = state.matchedLocation == Routes.username;
      if (!loggedIn && !onUsername) return Routes.username;
      if (loggedIn && onUsername) return Routes.home;
      return null;
    },
    routes: [
      GoRoute(
        path: Routes.username,
        builder: (context, state) => const UsernameScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.items,
                builder: (context, state) => const ItemsScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => AddEditItemScreen(
                      barcode: state.uri.queryParameters['barcode'],
                    ),
                  ),
                  GoRoute(
                    path: ':id',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => AddEditItemScreen(
                      itemId: int.tryParse(state.pathParameters['id']!),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.lists,
                builder: (context, state) => const ListsScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const AddEditListScreen(),
                  ),
                  GoRoute(
                    path: ':id',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => ListDetailScreen(
                      listId: int.parse(state.pathParameters['id']!),
                    ),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (context, state) => AddEditListScreen(
                          listId: int.parse(state.pathParameters['id']!),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.stores,
                builder: (context, state) => const StoresScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const AddEditStoreScreen(),
                  ),
                  GoRoute(
                    path: ':id',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => StoreDetailScreen(
                      storeId: int.parse(state.pathParameters['id']!),
                    ),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (context, state) => AddEditStoreScreen(
                          storeId: int.parse(state.pathParameters['id']!),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      // Full-screen flows outside the tab shell.
      GoRoute(
        path: '/scan',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => ScannerScreen(
          returnToListId: int.tryParse(state.uri.queryParameters['list'] ?? ''),
        ),
      ),
      GoRoute(
        path: '/scan/result',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => ScanResultScreen(
          barcode: state.uri.queryParameters['barcode'] ?? '',
          listId: int.tryParse(state.uri.queryParameters['list'] ?? ''),
        ),
      ),
      GoRoute(
        path: Routes.settings,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SettingsScreen(),
        routes: [
          GoRoute(
            path: 'categories',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) => const CategorySettingsScreen(),
          ),
          GoRoute(
            path: 'search-ai',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) => const LlmSettingsScreen(),
            routes: [
              GoRoute(
                path: 'debugger',
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) => const PipelineDebuggerScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
