import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/category.dart';
import '../../../core/providers/locale_provider.dart';

class CategorySelector extends StatelessWidget {
  final Category? selectedCategory;
  final List<Category> categories;
  final ValueChanged<Category?> onCategoryChanged;
  final VoidCallback onAddCategory;

  const CategorySelector({
    super.key,
    required this.selectedCategory,
    required this.categories,
    required this.onCategoryChanged,
    required this.onAddCategory,
  });

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final isRtl = locale.isRtl;
    final langCode = locale.locale?.languageCode ?? 'en';

    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<Category?>(
            value: selectedCategory,
            decoration: InputDecoration(
              labelText: isRtl ? 'التصنيف' : 'Category',
              prefixIcon: const Icon(Icons.category_outlined),
            ),
            items: [
              DropdownMenuItem<Category?>(
                value: null,
                child: Text(isRtl ? '— لا يوجد —' : '— None —'),
              ),
              ...categories.map(
                (c) => DropdownMenuItem<Category?>(
                  value: c,
                  child: Text(c.displayName(langCode)),
                ),
              ),
            ],
            onChanged: onCategoryChanged,
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          onPressed: onAddCategory,
          icon: const Icon(Icons.add),
          tooltip: isRtl ? 'إضافة تصنيف' : 'Add Category',
        ),
      ],
    );
  }
}
