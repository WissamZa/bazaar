import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/database/dao/store_dao.dart';
import '../../core/models/store.dart';
import '../../core/providers/data_change_notifier.dart';
import '../../core/providers/locale_provider.dart';

class AddEditStoreScreen extends StatefulWidget {
  final Store? store;
  const AddEditStoreScreen({super.key, this.store});

  @override
  State<AddEditStoreScreen> createState() => _AddEditStoreScreenState();
}

class _AddEditStoreScreenState extends State<AddEditStoreScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _nameAr;
  late final TextEditingController _website;
  late final TextEditingController _address;
  String? _imageUrl;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.store?.name ?? '');
    _nameAr = TextEditingController(text: widget.store?.nameAr ?? '');
    _website = TextEditingController(text: widget.store?.website ?? '');
    _address = TextEditingController(text: widget.store?.address ?? '');
    _imageUrl = widget.store?.imageUrl;
  }

  @override
  void dispose() {
    _name.dispose();
    _nameAr.dispose();
    _website.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;
    setState(() {
      _imageUrl = image.path;
    });
  }

  Future<void> _pickImageUrl() async {
    final ctrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          context.read<LocaleProvider>().isRtl ? 'رابط الصورة' : 'Image URL',
        ),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'https://...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              context.read<LocaleProvider>().isRtl ? 'إلغاء' : 'Cancel',
            ),
          ),
          FilledButton(
            onPressed: () {
              setState(() {
                _imageUrl = ctrl.text.trim();
              });
              Navigator.pop(ctx);
            },
            child: Text(context.read<LocaleProvider>().isRtl ? 'حفظ' : 'Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final en = _name.text.trim();
    final ar = _nameAr.text.trim();
    // Only the name is required — either EN or AR. The rest is optional.
    if (en.isEmpty && ar.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<LocaleProvider>().isRtl
                ? 'أدخل اسماً واحداً على الأقل (إنجليزي أو عربي)'
                : 'Enter at least one name (English or Arabic)',
          ),
        ),
      );
      return;
    }
    setState(() => _busy = true);
    final existing = widget.store;
    final store = Store(
      id: existing?.id,
      name: en,
      nameAr: ar.isEmpty ? null : ar,
      website: _website.text.trim().isEmpty ? null : _website.text.trim(),
      address: _address.text.trim().isEmpty ? null : _address.text.trim(),
      imageUrl: _imageUrl,
      createdAt: existing?.createdAt ?? DateTime.now(),
    );
    if (existing == null) {
      await StoreDao.instance.upsertByName(store);
    } else {
      await StoreDao.instance.update(store);
    }
    DataChangeNotifier.instance.notify(tag: 'store-saved');
    if (!mounted) return;
    setState(() => _busy = false);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final isRtl = locale.isRtl;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isRtl
              ? (widget.store == null ? 'متجر جديد' : 'تعديل المتجر')
              : (widget.store == null ? 'New Store' : 'Edit Store'),
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
                  labelText:
                      isRtl ? 'اسم المتجر (إنجليزي)' : 'Store Name (English)',
                  prefixIcon: const Icon(Icons.storefront_outlined),
                  helperText: isRtl
                      ? 'مطلوب: اسم واحد على الأقل (إنجليزي أو عربي)'
                      : 'Required: at least one name (EN or AR)',
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameAr,
                decoration: InputDecoration(
                  labelText: isRtl ? 'الاسم (عربي)' : 'Name (Arabic)',
                  prefixIcon: const Icon(Icons.label_outline),
                  helperText: isRtl ? 'اختياري' : 'Optional',
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 12),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: _pickImage,
                      icon: Icon(
                        _imageUrl == null ? Icons.image : Icons.check_circle,
                      ),
                      label: Text(
                        _imageUrl == null
                            ? (isRtl ? 'إضافة صورة' : 'Add Image')
                            : (isRtl ? 'تغيير الصورة' : 'Change Image'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: _pickImageUrl,
                    icon: const Icon(Icons.link),
                    label: Text(isRtl ? 'رابط' : 'URL'),
                  ),
                  if (_imageUrl != null)
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _imageUrl = null),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _address,
                decoration: InputDecoration(
                  labelText: isRtl ? 'العنوان' : 'Address',
                  prefixIcon: const Icon(Icons.location_on_outlined),
                  helperText: isRtl ? 'اختياري' : 'Optional',
                ),
                keyboardType: TextInputType.streetAddress,
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _website,
                decoration: InputDecoration(
                  labelText: isRtl ? 'الموقع الإلكتروني' : 'Website',
                  prefixIcon: const Icon(Icons.link),
                  helperText: isRtl ? 'اختياري' : 'Optional',
                  hintText: 'https://',
                ),
                keyboardType: TextInputType.url,
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
                label: Text(isRtl ? 'حفظ' : 'Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
