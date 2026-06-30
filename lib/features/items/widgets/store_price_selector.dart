import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/store.dart';
import '../../../core/providers/locale_provider.dart';

class StorePriceSelector extends StatelessWidget {
  final Set<Store> selectedStores;
  final List<Store> allStores;
  final Map<int, TextEditingController> priceControllers;
  final ValueChanged<Store> onStoreToggled;

  const StorePriceSelector({
    super.key,
    required this.selectedStores,
    required this.allStores,
    required this.priceControllers,
    required this.onStoreToggled,
  });

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final isRtl = locale.isRtl;
    final langCode = locale.locale?.languageCode ?? 'en';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          title: Text(isRtl ? 'المتاجر' : 'Stores'),
          subtitle: Text(
            selectedStores.isEmpty
                ? (isRtl ? 'لم يتم اختيار أي متجر' : 'No stores selected')
                : '${selectedStores.length} ${isRtl ? 'متاجر' : 'stores'}',
            style: const TextStyle(fontSize: 12),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showStoreSelector(context),
          shape: RoundedRectangleBorder(
            side: BorderSide(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        if (selectedStores.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            isRtl ? 'أسعار المتاجر' : 'Store Prices',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...selectedStores.map((store) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  Expanded(child: Text(store.displayName(langCode))),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: priceControllers[store.id],
                      decoration: InputDecoration(
                        labelText: isRtl ? 'السعر' : 'Price',
                        prefixIcon: const Icon(Icons.attach_money, size: 18),
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ],
    );
  }

  void _showStoreSelector(BuildContext context) {
    final locale = context.read<LocaleProvider>();
    final langCode = locale.locale?.languageCode ?? 'en';
    final isRtl = locale.isRtl;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(isRtl ? 'اختر المتاجر' : 'Select Stores'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  ...allStores
                      .map(
                        (s) => CheckboxListTile(
                          value: selectedStores.contains(s),
                          title: Text(s.displayName(langCode)),
                          onChanged: (v) {
                            onStoreToggled(s);
                            setDialogState(() {});
                          },
                        ),
                      )
                      .toList(),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(isRtl ? 'حفظ' : 'Done'),
              ),
            ],
          );
        },
      ),
    );
  }
}
