import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/providers/locale_provider.dart';

/// Inline toggle chip that switches between EN and AR.
class LanguageToggle extends StatelessWidget {
  const LanguageToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final isAr = locale.isRtl;
    return Tooltip(
      message: isAr ? 'Switch to English' : 'تبديل إلى العربية',
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => locale.toggle(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isAr ? Icons.language : Icons.translate,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(isAr ? 'EN' : 'ع'),
            ],
          ),
        ),
      ),
    );
  }
}
