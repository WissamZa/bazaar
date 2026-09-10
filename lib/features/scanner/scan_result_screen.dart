import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/currencies.dart';
import '../../core/design/app_dimens.dart';
import '../../core/design/components/app_image.dart';
import '../../core/design/components/empty_state.dart';
import '../../core/design/components/price_text.dart';
import '../../core/design/components/status_chip.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/settings_providers.dart';
import '../../core/services/barcode_service.dart';
import '../../core/services/scraping_config.dart';
import '../../core/services/scraper_service.dart';
import '../../core/models/models.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../core/router/app_router.dart';

/// Barcode lookup result: local hit, online hit, or not found. Lets the
/// user pick a specific source, then add the product to items or the
/// active list.
class ScanResultScreen extends ConsumerStatefulWidget {
  final String barcode;
  final int? listId;

  const ScanResultScreen({super.key, required this.barcode, this.listId});

  @override
  ConsumerState<ScanResultScreen> createState() => _ScanResultScreenState();
}

class _ScanResultScreenState extends ConsumerState<ScanResultScreen> {
  LookupSource _source = LookupSource.auto;
  bool _loading = true;
  bool _saving = false;
  BarcodeLookup? _result;
  final _cancel = CancelToken();

  @override
  void initState() {
    super.initState();
    _lookup();
  }

  @override
  void dispose() {
    _cancel.cancel();
    super.dispose();
  }

  Future<void> _lookup() async {
    setState(() => _loading = true);
    try {
      final lookup = await ref
          .read(barcodeServiceProvider)
          .lookupFromSource(widget.barcode, _source);
      if (!mounted || _cancel.isCancelled) return;
      setState(() {
        _result = lookup;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || _cancel.isCancelled) return;
      setState(() => _loading = false);
    }
  }

  String _sourceLabel(BuildContext context, LookupSource s) {
    final l = AppLocalizations.of(context)!;
    return switch (s) {
      LookupSource.auto => l.sourceAuto,
      LookupSource.openFoodFacts => l.sourceOpenFoodFacts,
      LookupSource.searxng => l.sourceSearxng,
    };
  }

  Future<void> _addToItems() async {
    final l = AppLocalizations.of(context)!;
    setState(() => _saving = true);
    try {
      final service = ref.read(barcodeServiceProvider);
      final local = _result?.localItem;
      final online = _result?.onlineProduct;
      if (local != null) {
        // Already saved — nothing to do.
      } else if (online != null) {
        await service.saveScrapedProduct(online, widget.barcode);
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.itemSaved)));
        context.pop();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.saveFailed)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final locale = ref.watch(
      localeProvider.select((s) => s?.languageCode ?? 'en'),
    );

    final local = _result?.localItem;
    final online = _result?.onlineProduct;

    return Scaffold(
      appBar: AppBar(title: Text(l.scanBarcode)),
      body: ListView(
        padding: AppDimens.pagePadding.copyWith(bottom: 24),
        children: [
          // Barcode + source picker
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.barcodeField,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      widget.barcode,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontFamily: 'AppMono',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.space3),
          DropdownButtonFormField<LookupSource>(
            initialValue: _source,
            decoration: InputDecoration(
              labelText: l.lookupSource,
              prefixIcon: const Icon(Icons.public, size: 20),
            ),
            items: [
              for (final s in LookupSource.values)
                DropdownMenuItem(
                  value: s,
                  child: Text(_sourceLabel(context, s)),
                ),
            ],
            onChanged: (v) {
              if (v == null || v == _source) return;
              setState(() => _source = v);
              _lookup();
            },
          ),
          const SizedBox(height: AppDimens.space5),

          if (_loading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppDimens.space8),
              child: Column(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: AppDimens.space4),
                  Text(
                    _source == LookupSource.auto
                        ? l.lookingUp
                        : l.searchingOnline,
                  ),
                ],
              ),
            )
          else if (local != null) ...[
            StatusChip(
              icon: Icons.inventory_2_rounded,
              label: l.scanResultFoundLocally,
              color: theme.colorScheme.secondary,
            ),
            const SizedBox(height: AppDimens.space3),
            _ProductCard(
              name: local.displayName(locale),
              brand: local.brand,
              imageUrl: local.imageUrl,
            ),
            const SizedBox(height: AppDimens.space4),
            FilledButton(
              onPressed: () => context.push(Routes.item(local.id)),
              child: Text(l.editItem),
            ),
          ] else if (online != null) ...[
            StatusChip(
              icon: Icons.cloud_done_outlined,
              label: l.scanResultFoundOnline,
              color: theme.colorScheme.secondary,
            ),
            const SizedBox(height: AppDimens.space3),
            _ProductCard(
              name: online.name,
              brand: online.brand,
              price: online.price,
              priceCurrency: currencyFromCode(online.currency),
              imageUrl: online.imageUrl,
              source: online.source,
            ),
            const SizedBox(height: AppDimens.space4),
            FilledButton.icon(
              onPressed: _saving ? null : _addToItems,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_shopping_cart_outlined, size: 18),
              label: Text(widget.listId != null ? l.addToList : l.addToItems),
            ),
          ] else ...[
            EmptyState(
              icon: Icons.search_off_rounded,
              title: l.scanResultNotFound,
              hint: l.scanResultNotFoundHint,
            ),
            const SizedBox(height: AppDimens.space4),
            OutlinedButton.icon(
              onPressed: () =>
                  context.push(Routes.newItem(barcode: widget.barcode)),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: Text(l.fillManually),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final String name;
  final String? brand;
  final double? price;
  final AppCurrency? priceCurrency;
  final String? imageUrl;
  final String? source;

  const _ProductCard({
    required this.name,
    this.brand,
    this.price,
    this.priceCurrency,
    this.imageUrl,
    this.source,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = ProviderScope.containerOf(context).read(currencyProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.space4),
        child: Row(
          children: [
            AppImage(url: imageUrl, size: 72),
            const SizedBox(width: AppDimens.space4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: theme.textTheme.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (brand != null && brand!.isNotEmpty)
                    Text(brand!, style: theme.textTheme.bodySmall),
                  if (source != null)
                    Text(
                      source!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (price != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: PriceText(
                        priceCurrency != null
                            ? priceCurrency!.convertTo(price!, currency)
                            : price,
                        currency: currency,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
