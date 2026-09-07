import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../app_dimens.dart';

/// − / count / + stepper used on list rows and in the item picker.
class QuantityStepper extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final int min;

  const QuantityStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppDimens.radiusM),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Button(
            icon: Icons.remove,
            tooltip: l.decreaseQuantity,
            onPressed: value > min ? () => onChanged(value - 1) : null,
          ),
          SizedBox(
            width: 30,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall,
            ),
          ),
          _Button(
            icon: Icons.add,
            tooltip: l.increaseQuantity,
            onPressed: () => onChanged(value + 1),
          ),
        ],
      ),
    );
  }
}

class _Button extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const _Button({required this.icon, required this.tooltip, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppDimens.radiusM),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            icon,
            size: 18,
            color: onPressed == null
                ? Theme.of(context).colorScheme.outline
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
