import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import 'package:go_router/go_router.dart';

import '../../core/database/app_database.dart';
import '../../core/providers/settings_providers.dart';

import '../../core/providers/database_provider.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../core/router/app_router.dart';

/// Create / rename a shopping list.
class AddEditListScreen extends ConsumerStatefulWidget {
  final int? listId;

  const AddEditListScreen({super.key, this.listId});

  @override
  ConsumerState<AddEditListScreen> createState() => _AddEditListScreenState();
}

class _AddEditListScreenState extends ConsumerState<AddEditListScreen> {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.listId == null) return;
    final row = await ref
        .read(databaseProvider)
        .shoppingListDao
        .findById(widget.listId!);
    if (row != null && mounted) {
      setState(() => _nameController.text = row.name);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final db = ref.read(databaseProvider);
      final owner = ref.read(userProvider) ?? 'local';
      final now = DateTime.now().toIso8601String();
      if (widget.listId == null) {
        final id = await db.shoppingListDao.insertList(
          ShoppingListsCompanion.insert(
            name: _nameController.text.trim(),
            owner: owner,
            createdAt: now,
            updatedAt: now,
          ),
        );
        if (mounted) {
          context.pushReplacement(Routes.list(id));
        }
      } else {
        await db.shoppingListDao.updateList(
          widget.listId!,
          ShoppingListsCompanion(
            name: Value(_nameController.text.trim()),
            updatedAt: Value(now),
          ),
        );
        if (mounted) context.pop();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.listId == null ? l.newList : l.editList),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _save(),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? l.listNameRequired : null,
                decoration: InputDecoration(
                  labelText: l.listNameField,
                  prefixIcon: const Icon(Icons.edit_note_outlined),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(l.commonSave),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
