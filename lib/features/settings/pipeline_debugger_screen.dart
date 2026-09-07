import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/app_dimens.dart';
import '../../core/design/app_typography.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/settings_providers.dart';
import '../../core/services/scraping_config.dart';
import '../../core/services/scraper_service.dart';
import '../../l10n/generated/app_localizations.dart';

/// Pipeline debugger: run one barcode through every tier and inspect what
/// each returned. Pure observability — nothing is written to the DB.
class PipelineDebuggerScreen extends ConsumerStatefulWidget {
  const PipelineDebuggerScreen({super.key});

  @override
  ConsumerState<PipelineDebuggerScreen> createState() =>
      _PipelineDebuggerScreenState();
}

class _PipelineDebuggerScreenState
    extends ConsumerState<PipelineDebuggerScreen> {
  final _barcodeController = TextEditingController();
  bool _running = false;
  PipelineDebugResult? _result;

  @override
  void dispose() {
    _barcodeController.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final barcode = _barcodeController.text.trim();
    if (barcode.isEmpty || _running) return;
    setState(() => _running = true);
    try {
      // Sync the live provider config into the singleton service first.
      ref.read(scrapingConfigProvider);
      final result = await ScraperService.instance.debugPipeline(barcode);
      if (mounted) setState(() => _result = result);
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l.pipelineDebugger)),
      body: ListView(
        padding: AppDimens.pagePadding.copyWith(bottom: 32),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _barcodeController,
                  keyboardType: TextInputType.number,
                  style: AppTypography.mono(context, size: 14),
                  onSubmitted: (_) => _run(),
                  decoration: InputDecoration(
                    labelText: l.pipelineBarcodeField,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: AppDimens.space2),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: FilledButton(
                  onPressed: _running ? null : _run,
                  child: _running
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l.runPipeline),
                ),
              ),
            ],
          ),
          if (_result != null) ...[
            const SizedBox(height: AppDimens.space4),
            // Final result
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppDimens.space4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.pipelineFinalResult,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppDimens.space2),
                    if (_result!.finalProduct != null) ...[
                      Text(
                        _result!.finalProduct!.name,
                        style: theme.textTheme.titleMedium,
                      ),
                      if (_result!.finalProduct!.brand != null)
                        Text(_result!.finalProduct!.brand!),
                      if (_result!.finalProduct!.price != null)
                        Text(
                          '${_result!.finalProduct!.price} ${_result!.finalProduct!.currency}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      Text(
                        _result!.finalProduct!.source,
                        style: theme.textTheme.bodySmall,
                      ),
                    ] else
                      Text(l.scanResultNotFound),
                  ],
                ),
              ),
            ),
            // Steps
            for (final step in _result!.steps) _StepCard(step: step),
            if (_result!.browserCompareUrl != null)
              Padding(
                padding: const EdgeInsets.only(top: AppDimens.space3),
                child: Center(
                  child: Text(
                    '${l.pipelineOpenInBrowser} · ${_result!.totalDuration.inMilliseconds} ms',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final PipelineDebugStep step;

  const _StepCard({required this.step});

  Color _color(BuildContext context) {
    final theme = Theme.of(context);
    return switch (step.status) {
      PipelineStepStatus.success => theme.colorScheme.secondary,
      PipelineStepStatus.noData => theme.colorScheme.tertiary,
      PipelineStepStatus.failed => theme.colorScheme.error,
      PipelineStepStatus.skipped => theme.colorScheme.onSurfaceVariant,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final statusLabel = switch (step.status) {
      PipelineStepStatus.success => l.statusSuccess,
      PipelineStepStatus.noData => l.statusNoData,
      PipelineStepStatus.failed => l.statusFailed,
      PipelineStepStatus.skipped => l.statusSkipped,
    };

    return Card(
      margin: const EdgeInsets.only(top: AppDimens.space2),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: step.status == PipelineStepStatus.failed,
        title: Row(
          children: [
            Icon(Icons.circle, size: 10, color: _color(context)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                step.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
        subtitle: Text(
          '$statusLabel · ${step.duration.inMilliseconds} ms',
          style: theme.textTheme.bodySmall?.copyWith(color: _color(context)),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          if (step.error != null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                step.error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          if (step.data != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                const JsonEncoder.withIndent('  ').convert(step.data),
                style: AppTypography.mono(context, size: 11),
              ),
            ),
        ],
      ),
    );
  }
}
