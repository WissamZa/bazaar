import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/database/dao/item_price_history_dao.dart';
import '../../../core/database/dao/item_store_dao.dart';
import '../../../core/database/dao/store_dao.dart';
import '../../../core/models/item_price_history.dart';
import '../../../core/models/item_store.dart';
import '../../../core/models/store.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../widgets/currency_display.dart';

class PriceHistoryList extends StatelessWidget {
  final int itemId;

  const PriceHistoryList({super.key, required this.itemId});

  Future<List<(Store, List<ItemPriceHistory>)>> _loadHistories() async {
    final storesInfo = await ItemStoreDao.instance.forItem(itemId);
    final result = <(Store, List<ItemPriceHistory>)>[];

    for (final info in storesInfo) {
      final store = await StoreDao.instance.findById(info.storeId);
      if (store == null) continue;
      final history = await ItemPriceHistoryDao.instance.forItemStore(info.id!);
      result.add((store, history));
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final isRtl = locale.isRtl;

    return FutureBuilder<List<(Store, List<ItemPriceHistory>)>>(
      future: _loadHistories(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final histories = snapshot.data ?? [];
        if (histories.isEmpty) {
          return Center(
            child: Text(
                isRtl ? 'لا يوجد تاريخ للأسعار' : 'No price history available'),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: histories.length,
          itemBuilder: (context, index) {
            final (store, history) = histories[index];
            return ExpansionTile(
              title:
                  Text(store.displayName(locale.locale?.languageCode ?? 'en')),
              children: history
                  .map((h) => ListTile(
                        leading: const Icon(Icons.history),
                        title: CurrencyDisplay(amount: h.price),
                        subtitle: Text(
                            h.recordedAt.toLocal().toString().split(' ')[0]),
                      ))
                  .toList(),
            );
          },
        );
      },
    );
  }
}
