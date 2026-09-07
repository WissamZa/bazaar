import 'dart:io';

import 'package:flutter/material.dart';

import '../app_dimens.dart';

/// Rounded thumbnail for an item/store image. Handles local file paths and
/// https URLs with a tinted fallback icon; network images are cached.
///
/// Replaces the `_placeholderIcon` helpers duplicated across v1 screens.
class AppImage extends StatelessWidget {
  final String? url;
  final double size;
  final IconData fallbackIcon;

  const AppImage({
    super.key,
    required this.url,
    this.size = AppDimens.listItemImage,
    this.fallbackIcon = Icons.local_grocery_store_outlined,
  });

  bool get _isFile => url != null && !url!.startsWith('http');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppDimens.radiusM),
      ),
      child: Icon(
        fallbackIcon,
        size: size * 0.5,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );

    if (url == null || url!.isEmpty) return placeholder;

    Widget image;
    if (_isFile) {
      image = Image.file(
        File(url!),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder,
      );
    } else {
      image = Image.network(
        url!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder,
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : placeholder,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDimens.radiusM),
      child: SizedBox(width: size, height: size, child: image),
    );
  }
}
