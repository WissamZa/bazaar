import 'package:flutter/material.dart';

import '../app_dimens.dart';

/// Dashboard KPI tile — icon in a tinted container plus a count and label.
class KpiCard extends StatelessWidget {
  final IconData icon;
  final int value;
  final String label;
  final Color accent;
  final VoidCallback? onTap;

  const KpiCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    required this.accent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: AppDimens.kpiIconBox,
                height: AppDimens.kpiIconBox,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AppDimens.radiusM),
                ),
                child: Icon(icon, size: 20, color: accent),
              ),
              const SizedBox(height: AppDimens.space3),
              Text('$value', style: theme.textTheme.headlineSmall),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
