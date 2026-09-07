import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/design/app_dimens.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../core/router/app_router.dart';

/// Camera barcode scanner. Returns the scanned code as a [String] route
/// result, or (when [returnToListId] is set) navigates straight to the
/// lookup result screen bound to that list.
class ScannerScreen extends ConsumerStatefulWidget {
  final int? returnToListId;

  const ScannerScreen({super.key, this.returnToListId});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  MobileScannerController? _controller;
  bool _completed = false;
  bool _torchOn = false;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _ensureController() async {
    if (_controller != null) return;
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      formats: const [
        BarcodeFormat.ean13,
        BarcodeFormat.ean8,
        BarcodeFormat.upcA,
        BarcodeFormat.upcE,
        BarcodeFormat.code128,
      ],
    );
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_completed) return;
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null || code.isEmpty) return;
    _completed = true;
    HapticFeedback.mediumImpact();
    if (!mounted) return;
    if (widget.returnToListId != null) {
      context.pushReplacement(
        Routes.scanResult(code, listId: widget.returnToListId.toString()),
      );
    } else {
      context.pushReplacement(Routes.scanResult(code));
    }
  }

  Future<void> _openManualEntry() async {
    final l = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.enterManually),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(labelText: l.barcodeManualInput),
          onSubmitted: (v) => Navigator.of(context).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(l.continueLabel),
          ),
        ],
      ),
    );
    controller.dispose();
    if (code == null || code.isEmpty || !mounted) return;
    _completed = true;
    if (widget.returnToListId != null) {
      context.pushReplacement(
        Routes.scanResult(code, listId: widget.returnToListId.toString()),
      );
    } else {
      context.pushReplacement(Routes.scanResult(code));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text(l.scannerTitle),
        actions: [
          IconButton(
            tooltip: l.enterManually,
            icon: const Icon(Icons.keyboard_alt_outlined),
            onPressed: _openManualEntry,
          ),
          IconButton(
            icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off),
            onPressed: () async {
              await _controller?.toggleTorch();
              setState(() => _torchOn = !_torchOn);
            },
          ),
        ],
      ),
      body: FutureBuilder<PermissionStatus>(
        future: Permission.camera.request(),
        builder: (context, snapshot) {
          final status = snapshot.data;
          if (status == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!status.isGranted) {
            return _PermissionDenied(onOpenSettings: openAppSettings);
          }
          _ensureController();
          return Stack(
            alignment: Alignment.center,
            children: [
              MobileScanner(
                controller: _controller,
                onDetect: _onDetect,
                errorBuilder: (context, error) => Center(
                  child: Text(
                    '${l.commonError}\n$error',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
              // Reticle
              IgnorePointer(
                child: Container(
                  width: AppDimens.scanReticle,
                  height: AppDimens.scanReticle * 0.62,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppDimens.radiusL),
                    border: Border.all(
                      color: theme.colorScheme.primary,
                      width: 2.5,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 64,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    l.scanning,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PermissionDenied extends StatelessWidget {
  final Future<void> Function() onOpenSettings;

  const _PermissionDenied({required this.onOpenSettings});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.space6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography_outlined, size: 56),
            const SizedBox(height: AppDimens.space4),
            Text(
              l.cameraPermissionRequired,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppDimens.space4),
            FilledButton.icon(
              onPressed: onOpenSettings,
              icon: const Icon(Icons.settings_outlined, size: 18),
              label: Text(l.commonOpenSettings),
            ),
          ],
        ),
      ),
    );
  }
}
