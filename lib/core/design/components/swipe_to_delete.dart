import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../app_dimens.dart';

/// Dismissible wrapper with the shared red delete background and
/// confirm-first behavior. v1 duplicated this in items + stores screens.
class SwipeToDelete extends StatelessWidget {
  final Widget child;
  final String confirmTitle;
  final String confirmMessage;
  final VoidCallback onConfirmed;

  const SwipeToDelete({
    super.key,
    required this.child,
    required this.confirmTitle,
    required this.confirmMessage,
    required this.onConfirmed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;
    return Dismissible(
      key: ValueKey('swipe-$confirmTitle'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsetsDirectional.only(end: AppDimens.space5),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(AppDimens.radiusM),
        ),
        child: Icon(Icons.delete_outline, color: theme.colorScheme.error),
      ),
      confirmDismiss: (_) async {
        final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(confirmTitle),
            content: Text(confirmMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l.commonCancel),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l.commonDelete),
              ),
            ],
          ),
        );
        if (ok == true) onConfirmed();
        return false; // removal is handled by the data stream, not the swipe
      },
      child: child,
    );
  }
}
