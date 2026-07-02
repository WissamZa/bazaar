import 'package:flutter/foundation.dart';

/// Global notifier that fires whenever ANY persistent data changes (items,
/// stores, lists, list_items, item_store links, price history).
///
/// Screens that display lists of data should `listen` to this and refresh
/// themselves when notified. This avoids the brittle pattern of passing
/// refresh callbacks through Navigator.push / pop return values.
///
/// Why a global instead of per-entity notifiers?
///   - Many screens cross-reference multiple entities (e.g. the Items screen
///     shows item + store link + price; the Store detail screen shows items
///     + price history). A single notifier keeps them all in sync without
///     each screen needing to subscribe to multiple streams.
///   - The app is local-first and single-user — broadcast refresh is cheap.
class DataChangeNotifier extends ChangeNotifier {
  DataChangeNotifier._();
  static final DataChangeNotifier instance = DataChangeNotifier._();

  /// Notify listeners that some data changed. Optionally pass a [tag] for
  /// debugging — appears in dev logs as `[data-changed] tag=...`.
  void notify({String? tag}) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('[data-changed] tag=${tag ?? '(none)'}');
    }
    notifyListeners();
  }
}
