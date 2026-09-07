import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/database/app_database.dart';
import '../../core/design/app_dimens.dart';
import '../../core/design/components/app_image.dart';
import '../../core/providers/database_provider.dart';
import '../../l10n/generated/app_localizations.dart';

/// Create / edit a store (bilingual name, website, address, image).
class AddEditStoreScreen extends ConsumerStatefulWidget {
  final int? storeId;

  const AddEditStoreScreen({super.key, this.storeId});

  @override
  ConsumerState<AddEditStoreScreen> createState() => _AddEditStoreScreenState();
}

class _AddEditStoreScreenState extends ConsumerState<AddEditStoreScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _nameAr = TextEditingController();
  final _website = TextEditingController();
  final _address = TextEditingController();
  final _imageUrl = TextEditingController();
  String? _localImagePath;
  bool _saving = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.storeId == null) return;
    setState(() => _loading = true);
    final db = ref.read(databaseProvider);
    final row = await db.storeDao.findById(widget.storeId!);
    if (row != null && mounted) {
      _name.text = row.name;
      _nameAr.text = row.nameAr ?? '';
      _website.text = row.website ?? '';
      _address.text = row.address ?? '';
      _imageUrl.text = row.imageUrl ?? '';
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _nameAr.dispose();
    _website.dispose();
    _address.dispose();
    _imageUrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final db = ref.read(databaseProvider);
      final image = _imageUrl.text.trim().isNotEmpty
          ? _imageUrl.text.trim()
          : _localImagePath;

      if (widget.storeId == null) {
        await db.storeDao.insertStore(
          StoresCompanion.insert(
            name: _name.text.trim(),
            createdAt: DateTime.now().toIso8601String(),
            nameAr: Value(
              _nameAr.text.trim().isEmpty ? null : _nameAr.text.trim(),
            ),
            website: Value(
              _website.text.trim().isEmpty ? null : _website.text.trim(),
            ),
            address: Value(
              _address.text.trim().isEmpty ? null : _address.text.trim(),
            ),
            imageUrl: Value(image),
          ),
        );
      } else {
        await db.storeDao.updateStore(
          widget.storeId!,
          StoresCompanion(
            name: Value(_name.text.trim()),
            nameAr: Value(
              _nameAr.text.trim().isEmpty ? null : _nameAr.text.trim(),
            ),
            website: Value(
              _website.text.trim().isEmpty ? null : _website.text.trim(),
            ),
            address: Value(
              _address.text.trim().isEmpty ? null : _address.text.trim(),
            ),
            imageUrl: Value(image),
          ),
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.storeSaved)));
        context.pop();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickImage() async {
    final xfile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
    );
    if (xfile != null) setState(() => _localImagePath = xfile.path);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.storeId == null ? l.newStore : l.editStore),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: AppDimens.pagePadding.copyWith(bottom: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Stack(
                        children: [
                          AppImage(
                            url: _imageUrl.text.isNotEmpty
                                ? _imageUrl.text
                                : _localImagePath,
                            size: 96,
                            fallbackIcon: Icons.storefront_outlined,
                          ),
                          Positioned.directional(
                            textDirection: Directionality.of(context),
                            end: -8,
                            bottom: -8,
                            child: IconButton.filledTonal(
                              onPressed: _pickImage,
                              icon: const Icon(
                                Icons.photo_camera_outlined,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDimens.space4),
                    TextFormField(
                      controller: _name,
                      textInputAction: TextInputAction.next,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? l.storeNameRequired
                          : null,
                      decoration: InputDecoration(
                        labelText: l.storeNameField,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: AppDimens.space3),
                    TextFormField(
                      controller: _nameAr,
                      textDirection: TextDirection.rtl,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: l.storeNameArField,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: AppDimens.space3),
                    TextFormField(
                      controller: _website,
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: l.websiteField,
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.link, size: 20),
                      ),
                    ),
                    const SizedBox(height: AppDimens.space3),
                    TextFormField(
                      controller: _address,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: l.addressField,
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(
                          Icons.location_on_outlined,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppDimens.space3),
                    TextFormField(
                      controller: _imageUrl,
                      decoration: InputDecoration(
                        labelText: l.imageUrlField,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: AppDimens.space5),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(
                          AppDimens.minTouchTarget,
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l.commonSave),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
