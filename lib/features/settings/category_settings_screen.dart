import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/database/dao/category_dao.dart';
import '../../core/models/category.dart';
import '../../core/providers/locale_provider.dart';

class CategorySettingsScreen extends StatefulWidget {
  const CategorySettingsScreen({super.key});

  @override
  State<CategorySettingsScreen> createState() => _CategorySettingsScreenState();
}

class _CategorySettingsScreenState extends State<CategorySettingsScreen> {
  List<Category> _categories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    _categories = await CategoryDao.instance.all();
    setState(() => _loading = false);
  }

  Future<void> _openAddEdit({Category? category}) async {
    final ctrl = TextEditingController(text: category?.name ?? '');
    final arCtrl = TextEditingController(text: category?.nameAr ?? '');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.read<LocaleProvider>().isRtl
            ? (category == null ? 'إضافة تصنيف' : 'تعديل تصنيف')
            : (category == null ? 'Add Category' : 'Edit Category')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              decoration: InputDecoration(
                  labelText: context.read<LocaleProvider>().isRtl
                      ? 'الاسم (إنجليزي)'
                      : 'Name (English)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: arCtrl,
              decoration: InputDecoration(
                  labelText: context.read<LocaleProvider>().isRtl
                      ? 'الاسم (عربي)'
                      : 'Name (Arabic)'),
              textDirection: TextDirection.rtl,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                  context.read<LocaleProvider>().isRtl ? 'إلغاء' : 'Cancel')),
          FilledButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              final nameAr = arCtrl.text.trim();
              if (name.isEmpty) return;

              if (category == null) {
                await CategoryDao.instance.insert(Category(
                  name: name,
                  nameAr: nameAr.isEmpty ? null : nameAr,
                  createdAt: DateTime.now(),
                ));
              } else {
                await CategoryDao.instance.update(category.copyWith(
                  name: name,
                  nameAr: nameAr.isEmpty ? null : nameAr,
                ));
              }
              Navigator.pop(ctx);
              _refresh();
            },
            child: Text(context.read<LocaleProvider>().isRtl ? 'حفظ' : 'Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final isRtl = locale.isRtl;

    return Scaffold(
      appBar: AppBar(
        title: Text(isRtl ? 'إدارة التصنيفات' : 'Category Management'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _categories.isEmpty
              ? Center(child: Text(isRtl ? 'لا توجد تصنيفات' : 'No categories'))
              : ListView.builder(
                  itemCount: _categories.length,
                  itemBuilder: (_, i) {
                    final cat = _categories[i];
                    return ListTile(
                      title: Text(
                          cat.displayName(locale.locale?.languageCode ?? 'en')),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _openAddEdit(category: cat),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () async {
                              await CategoryDao.instance.delete(cat.id!);
                              _refresh();
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddEdit(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
