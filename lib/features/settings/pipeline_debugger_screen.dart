import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform, Process;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/providers/locale_provider.dart';
import '../../core/providers/scraping_provider.dart';
import '../../core/services/scraper_service.dart';

/// Pipeline Debugger — lets the user enter a barcode and see EXACTLY what
/// each tier of the scraper returned. Useful for:
///   - Verifying the on-device LLM actually works (vs. just trusting the
///     final result)
///   - Comparing the app's extraction to a manual browser search
///   - Figuring out why a particular barcode "returns nothing"
class PipelineDebuggerScreen extends StatefulWidget {
  const PipelineDebuggerScreen({super.key});

  @override
  State<PipelineDebuggerScreen> createState() => _PipelineDebuggerScreenState();
}

class _PipelineDebuggerScreenState extends State<PipelineDebuggerScreen> {
  final _barcodeCtrl = TextEditingController();
  bool _running = false;
  PipelineDebugResult? _result;

  @override
  void dispose() {
    _barcodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final barcode = _barcodeCtrl.text.trim();
    if (barcode.isEmpty) return;
    setState(() {
      _running = true;
      _result = null;
    });
    try {
      final result =
          await ScraperService.instance.debugPipeline(barcode);
      if (!mounted) return;
      setState(() => _result = result);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  Future<void> _openInBrowser(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;

    // Desktop platforms: spawn the system URL opener via dart:io.
    // No extra Flutter plugin dependency required.
    if (!kIsWeb && (Platform.isLinux || Platform.isMacOS || Platform.isWindows)) {
      String cmd;
      List<String> args;
      if (Platform.isLinux) {
        cmd = 'xdg-open';
        args = [url];
      } else if (Platform.isMacOS) {
        cmd = 'open';
        args = [url];
      } else {
        // Windows: `start` is a cmd builtin so we have to run it through cmd.
        cmd = 'cmd';
        args = ['/c', 'start', '', url];
      }
      try {
        final result = await Process.run(cmd, args);
        if (result.exitCode != 0) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Could not open browser ($cmd exit ${result.exitCode}): '
                '${result.stderr}'.trim(),
              ),
              action: SnackBarAction(
                label: 'Copy URL',
                onPressed: () =>
                    Clipboard.setData(ClipboardData(text: url)),
              ),
            ),
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cannot launch $cmd: $e'),
            action: SnackBarAction(
              label: 'Copy URL',
              onPressed: () =>
                  Clipboard.setData(ClipboardData(text: url)),
            ),
          ),
        );
      }
      return;
    }

    // Mobile / Web: copy to clipboard and prompt the user to paste in a
    // browser. (We could add url_launcher as a dependency for native mobile
    // launching, but that adds a plugin + native setup for what's a rare
    // debug-only action.)
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('URL copied to clipboard — paste it in your browser:\n$url'),
        duration: const Duration(seconds: 6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final isRtl = locale.isRtl;
    final scraping = context.watch<ScrapingProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(isRtl ? 'تنقيح خط الأنابيب' : 'Pipeline Debugger'),
      ),
      body: Column(
        children: [
          // ── Barcode input ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _barcodeCtrl,
                    decoration: InputDecoration(
                      labelText: isRtl ? 'الباركود' : 'Barcode',
                      hintText: 'e.g. 6970530854708',
                      prefixIcon: const Icon(Icons.barcode_reader),
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onSubmitted: (_) => _run(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _running ? null : _run,
                  icon: _running
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow),
                  label: Text(isRtl ? 'تشغيل' : 'Run'),
                ),
              ],
            ),
          ),

          // ── Current strategy banner ───────────────────────────────────
          Container(
            width: double.infinity,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.settings_outlined,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isRtl
                        ? 'الاستراتيجية الحالية: ${scraping.strategy.displayName('ar')}'
                        : 'Current strategy: ${scraping.strategy.displayName('en')}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // ── Result ────────────────────────────────────────────────────
          Expanded(
            child: _result == null
                ? _buildEmptyState(isRtl)
                : _buildResult(isRtl),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isRtl) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bug_report_outlined,
                size: 64, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              isRtl
                  ? 'أدخل باركود واضغط تشغيل لرؤية كل خطوة'
                  : 'Enter a barcode and tap Run to see every step',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              isRtl
                  ? 'مفيد للتأكد من أن LLM المحلي يعمل، أو لمعرفة لماذا يفشل بحث معين'
                  : 'Useful to verify the on-device LLM is working, or to find out why a specific lookup fails',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResult(bool isRtl) {
    final r = _result!;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // ── Final result card ──────────────────────────────────────────
        _FinalResultCard(result: r, isRtl: isRtl),
        const SizedBox(height: 12),

        // ── Open in browser button ─────────────────────────────────────
        if (r.browserCompareUrl != null)
          FilledButton.tonalIcon(
            onPressed: () => _openInBrowser(r.browserCompareUrl),
            icon: const Icon(Icons.open_in_browser),
            label: Text(isRtl
                ? 'افتح نفس البحث في المتصفح للمقارنة'
                : 'Open same search in browser to compare'),
          ),
        const SizedBox(height: 12),

        // ── Steps breakdown ────────────────────────────────────────────
        Text(
          isRtl ? 'تفصيل الخطوات' : 'Steps breakdown',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        for (int i = 0; i < r.steps.length; i++)
          _StepCard(step: r.steps[i], index: i + 1, isRtl: isRtl),

        const SizedBox(height: 24),
        // ── SearXNG raw results ────────────────────────────────────────
        if (r.searxngResults.isNotEmpty) ...[
          Text(
            isRtl ? 'نتائج SearXNG الخام' : 'Raw SearXNG results',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          for (int i = 0; i < r.searxngResults.length; i++)
            _SearxngResultCard(
              result: r.searxngResults[i],
              index: i + 1,
              onTap: () => _openInBrowser(
                  r.searxngResults[i]['url'] as String?),
            ),
        ],
      ],
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
// Final result card
// ───────────────────────────────────────────────────────────────────────────
class _FinalResultCard extends StatelessWidget {
  final PipelineDebugResult result;
  final bool isRtl;
  const _FinalResultCard({required this.result, required this.isRtl});

  @override
  Widget build(BuildContext context) {
    final p = result.finalProduct;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.celebration_outlined,
                    color: p != null
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.error),
                const SizedBox(width: 8),
                Text(
                  isRtl ? 'النتيجة النهائية' : 'Final result',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                Text(
                  '${result.totalDuration.inMilliseconds} ms',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const Divider(),
            if (p == null)
              Text(
                isRtl ? 'لم يُعثر على شيء' : 'Nothing found',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.error),
              )
            else ...[
              _kv('Name', p.name),
              if (p.brand != null) _kv('Brand', p.brand!),
              if (p.nameAr != null) _kv('Name (AR)', p.nameAr!),
              _kv('Price',
                  p.price == null ? '—' : '${p.currency} ${p.price}'),
              _kv('Source', p.source),
              if (p.imageUrl != null)
                _kv('Image', p.imageUrl!, copyable: true),
            ],
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v, {bool copyable = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(k,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(child: Text(v)),
          if (copyable)
            IconButton(
              icon: const Icon(Icons.copy, size: 14),
              onPressed: () => Clipboard.setData(ClipboardData(text: v)),
              tooltip: 'Copy',
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
// Step card
// ───────────────────────────────────────────────────────────────────────────
class _StepCard extends StatelessWidget {
  final PipelineDebugStep step;
  final int index;
  final bool isRtl;
  const _StepCard(
      {required this.step, required this.index, required this.isRtl});

  @override
  Widget build(BuildContext context) {
    final color = switch (step.status) {
      PipelineStepStatus.success => Colors.green,
      PipelineStepStatus.noData => Colors.orange,
      PipelineStepStatus.failed => Colors.red,
      PipelineStepStatus.skipped => Colors.grey,
    };
    final icon = switch (step.status) {
      PipelineStepStatus.success => Icons.check_circle,
      PipelineStepStatus.noData => Icons.remove_circle_outline,
      PipelineStepStatus.failed => Icons.error,
      PipelineStepStatus.skipped => Icons.skip_next,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: Icon(icon, color: color, size: 20),
        title: Text(step.name,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        subtitle: Text(
          '${step.status.label} · ${step.duration.inMilliseconds} ms'
          '${step.error != null ? ' · ${step.error}' : ''}',
          style: TextStyle(fontSize: 11, color: color),
        ),
        children: [
          if (step.data != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _buildData(step.data!),
            ),
        ],
      ),
    );
  }

  Widget _buildData(Map<String, dynamic> data) {
    final pretty = const JsonEncoder.withIndent('  ').convert(data);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(4),
      ),
      child: SelectableText(
        pretty,
        style: const TextStyle(
          fontFamily: 'RobotoMono',
          fontSize: 11,
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
// SearXNG result card
// ───────────────────────────────────────────────────────────────────────────
class _SearxngResultCard extends StatelessWidget {
  final Map<String, dynamic> result;
  final int index;
  final VoidCallback onTap;
  const _SearxngResultCard(
      {required this.result, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final title = result['title'] as String? ?? '(no title)';
    final url = result['url'] as String? ?? '';
    final engine = result['engine'] as String? ?? '';
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: CircleAvatar(
          radius: 12,
          child: Text('$index', style: const TextStyle(fontSize: 11)),
        ),
        title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(url, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: engine.isEmpty
            ? null
            : Chip(label: Text(engine, style: const TextStyle(fontSize: 10))),
        onTap: onTap,
      ),
    );
  }
}
