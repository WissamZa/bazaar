import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/database/dao/shopping_list_dao.dart';
import '../../core/models/shopping_list.dart';
import '../../core/providers/locale_provider.dart';
import '../../core/providers/user_provider.dart';

class AddEditListScreen extends StatefulWidget {
  final ShoppingList? list;
  const AddEditListScreen({super.key, this.list});

  @override
  State<AddEditListScreen> createState() => _AddEditListScreenState();
}

class _AddEditListScreenState extends State<AddEditListScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.list?.name ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    final now = DateTime.now();
    final owner = context.read<UserProvider>().username ?? 'local';
    final existing = widget.list;
    final list = ShoppingList(
      id: existing?.id,
      name: _name.text.trim(),
      nameAr: null,
      owner: existing?.owner ?? owner,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    if (existing == null) {
      await ShoppingListDao.instance.upsertByName(list);
    } else {
      await ShoppingListDao.instance.update(list);
    }
    if (!mounted) return;
    setState(() => _busy = false);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          locale.isRtl
              ? (widget.list == null ? 'قائمة جديدة' : 'تعديل القائمة')
              : (widget.list == null ? 'New List' : 'Edit List'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _name,
                decoration: InputDecoration(
                  labelText: locale.isRtl ? 'اسم القائمة' : 'List Name',
                  prefixIcon: const Icon(Icons.label_outline),
                ),
                textInputAction: TextInputAction.next,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? (locale.isRtl ? 'مطلوب' : 'Required')
                    : null,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _busy ? null : _save,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(locale.isRtl ? 'حفظ' : 'Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
