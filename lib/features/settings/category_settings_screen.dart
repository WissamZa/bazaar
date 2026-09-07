import 'package:drift/drift.dart' show Value;

import '../../core/database/app_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/app_dimens.dart';
import '../../core/design/components/empty_state.dart';
import '../../core/design/components/swipe_to_delete.dart';
import '../../core/models/models.dart';
import '../../core/providers/data_providers.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/settings_providers.dart';
import '../../l10n/generated/app_localizations.dart';

/// Category CRUD.
class CategorySettingsScreen extends ConsumerWidget {
  const CategorySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final categories = ref.watch(categoriesStreamProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.manageCategories)),
      body: categories.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (rows) {
          if (rows.isEmpty) {
            return EmptyState(
              icon: Icons.category_outlined,
              title: l.manageCategories,
              hint: l.addCategory,
              actionLabel: l.addCategory,
              onAction: () => _editCategory(context, ref, null),
            );
          }
          return ListView.builder(
            padding: AppDimens.pagePadding,
            itemCount: rows.length,
            itemBuilder: (context, i) {
              final row = rows[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: AppDimens.space2),
                child: SwipeToDelete(
                  confirmTitle: l.deleteCategoryTitle,
                  confirmMessage: l.deleteCategoryMessage,
                  onConfirmed: () => ref
                      .read(databaseProvider)
                      .categoryDao
                      .deleteCategory(row.id),
                  child: Card(
                    child: ListTile(
                      title: Text(
                        row.displayName(
                          ref.read(localeProvider.notifier).effectiveCode,
                        ),
                      ),
                      onTap: () =>
                          _editCategory(context, ref, Category.fromRow(row)),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'category-fab',
        onPressed: () => _editCategory(context, ref, null),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _editCategory(
    BuildContext context,
    WidgetRef ref,
    Category? existing,
  ) async {
    final l = AppLocalizations.of(context)!;
    final nameEn = TextEditingController(text: existing?.name ?? '');
    final nameAr = TextEditingController(text: existing?.nameAr ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? l.addCategory : l.commonEdit),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameEn,
              autofocus: true,
              decoration: InputDecoration(labelText: l.categoryNameEn),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameAr,
              textDirection: TextDirection.rtl,
              decoration: InputDecoration(labelText: l.categoryNameAr),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.commonSave),
          ),
        ],
      ),
    );

    nameEn.dispose();
    nameAr.dispose();
    if (saved != true) return;

    final db = ref.read(databaseProvider);
    final now = DateTime.now();
    if (existing == null) {
      await db.categoryDao.insertCategory(
        CategoriesCompanion.insert(
          name: nameEn.text.trim().isEmpty
              ? nameAr.text.trim()
              : nameEn.text.trim(),
          createdAt: now.toIso8601String(),
          nameAr: Value(nameAr.text.trim().isEmpty ? null : nameAr.text.trim()),
        ),
      );
    } else {
      await db.categoryDao.updateCategory(
        existing.id!,
        existing
            .copyWith(
              name: nameEn.text.trim(),
              nameAr: nameAr.text.trim().isEmpty ? null : nameAr.text.trim(),
            )
            .toUpdateCompanion(),
      );
    }
  }
}
