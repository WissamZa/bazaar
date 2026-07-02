import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/store.dart';
import '../../../core/providers/locale_provider.dart';

/// Widget for picking which stores carry this item + entering the price
/// for each, AND for picking which store's price should be shown as the
/// item's "main" price in the items list.
class StorePriceSelector extends StatelessWidget {
  final Set<Store> selectedStores;
  final List<Store> allStores;
  final Map<int, TextEditingController> priceControllers;
  final ValueChanged<Store> onStoreToggled;
  /// Called when the user picks a different "main" store via the radio
  /// button. Pass null to clear the preference (means "use lowest").
  final ValueChanged<int?> onPreferredStoreChanged;
  /// The currently-preferred store ID, or null if no preference.
  final int? preferredStoreId;

  const StorePriceSelector({
    super.key,
    required this.selectedStores,
    required this.allStores,
    required this.priceControllers,
    required this.onStoreToggled,
    required this.onPreferredStoreChanged,
    required this.preferredStoreId,
  });

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final isRtl = locale.isRtl;
    final langCode = locale.locale?.languageCode ?? 'en';

    // Sort selected stores by name so the radio list is stable.
    final sortedStores = selectedStores.toList()
      ..sort((a, b) => a.displayName(langCode).toLowerCase().compareTo(
          b.displayName(langCode).toLowerCase()));

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
          Row(
            children: [
              Text(
                isRtl ? 'أسعار المتاجر' : 'Store Prices',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: isRtl
                    ? 'اختر المتجر الذي يظهر سعره بجانب اسم المنتج في القائمة'
                    : 'Pick which store\'s price shows next to the item name in the list',
                child: Icon(Icons.info_outline,
                    size: 14,
                    color: Theme.of(context).colorScheme.outline),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Header row: "Main" | "Store" | "Price"
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 48,
                  child: Text(
                    isRtl ? 'رئيسي' : 'Main',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  child: Text(
                    isRtl ? 'المتجر' : 'Store',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    isRtl ? 'السعر' : 'Price',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
          ),
          ...sortedStores.map((store) {
            final isPreferred = preferredStoreId == store.id;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  // Radio button to mark this store as the "main" price source.
                  SizedBox(
                    width: 48,
                    child: Radio<int?>(
                      value: store.id,
                      groupValue: preferredStoreId,
                      onChanged: (v) => onPreferredStoreChanged(v),
                    ),
                  ),
                  Expanded(child: Text(store.displayName(langCode))),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: priceControllers[store.id],
                      decoration: InputDecoration(
                        labelText: isRtl ? 'السعر' : 'Price',
                        prefixIcon: const Icon(Icons.attach_money, size: 18),
                        // Visually highlight the preferred store's price field.
                        filled: isPreferred,
                        fillColor: isPreferred
                            ? Theme.of(context)
                                .colorScheme
                                .primaryContainer
                                .withValues(alpha: 0.3)
                            : null,
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          // "Use lowest" option — clears the preferred store.
          if (selectedStores.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 48,
                    child: Radio<int?>(
                      value: null,
                      groupValue: preferredStoreId,
                      onChanged: (v) => onPreferredStoreChanged(v),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      isRtl
                          ? 'استخدم أقل سعر (تلقائي)'
                          : 'Use lowest price (auto)',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
