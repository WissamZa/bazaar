import 'package:flutter/material.dart';

/// Small tinted chip for statuses (found / not found / success / warning).
/// Colors always come from the theme scheme, never raw `Colors.*`.
class StatusChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color? background;

  const StatusChip({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    this.background,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background ?? color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
