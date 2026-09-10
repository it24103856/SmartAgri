import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../constants/api_constants.dart';

class ProfileAvatar extends StatelessWidget {
  final String? url;
  final Uint8List? bytes;
  final double radius;
  const ProfileAvatar({super.key, this.url, this.bytes, this.radius = 24});

  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: const Color(0xFFE2EBE5),
      child: Center(
        child: Icon(
          Icons.person_outline,
          color: const Color(0xFF3B6E52),
          size: radius,
        ),
      ),
    );
    Widget photo = fallback;
    if (bytes != null) {
      photo = Image.memory(
        bytes!,
        fit: BoxFit.cover,
        errorBuilder: (_, error, stack) => fallback,
      );
    } else if (url != null && url!.isNotEmpty) {
      final uri = Uri.parse(ApiConstants.baseUrl).resolve(url!);
      if (uri.scheme == 'http' || uri.scheme == 'https') {
        photo = Image.network(
          uri.toString(),
          fit: BoxFit.cover,
          errorBuilder: (_, error, stack) => fallback,
          loadingBuilder: (_, child, progress) =>
              progress == null ? child : fallback,
        );
      }
    }
    return ClipOval(
      child: SizedBox(width: radius * 2, height: radius * 2, child: photo),
    );
  }
}
