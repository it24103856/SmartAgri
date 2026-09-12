import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/constants/api_constants.dart';

class ProfileAvatar extends StatelessWidget {
  final String? imageUrl;
  final Uint8List? preview;
  final double size;

  const ProfileAvatar({
    super.key,
    this.imageUrl,
    this.preview,
    this.size = 104,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    Widget fallback() => ColoredBox(
      color: colors.primaryContainer,
      child: Center(
        child: Icon(
          Icons.person_rounded,
          size: size * 0.55,
          color: colors.primary,
        ),
      ),
    );

    Widget content = fallback();

    if (preview != null) {
      content = Image.memory(
        preview!,
        fit: BoxFit.cover,
        errorBuilder: (_, error, stackTrace) => fallback(),
      );
    } else if (imageUrl?.trim().isNotEmpty ?? false) {
      final url = Uri.parse(
        ApiConstants.baseUrl,
      ).resolve(imageUrl!.trim()).toString();

      content = Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, error, stackTrace) => fallback(),
      );
    }

    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.surface,
        border: Border.all(
          color: colors.primary.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: ClipOval(child: content),
    );
  }
}
