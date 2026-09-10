import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'auth_service.dart';

class ProfilePhoto {
  final Uint8List bytes;
  final String name;
  const ProfilePhoto(this.bytes, this.name);

  static Future<ProfilePhoto?> pick() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
        requestFullMetadata: false,
      );
      if (file == null) return null;
      if (await file.length() > 5 * 1024 * 1024) {
        throw AuthException('Choose a photo smaller than 5 MB.');
      }
      final bytes = await file.readAsBytes();
      final jpg =
          bytes.length >= 12 &&
          bytes[0] == 255 &&
          bytes[1] == 216 &&
          bytes[2] == 255;
      final png =
          bytes.length >= 12 &&
          bytes[0] == 137 &&
          bytes[1] == 80 &&
          bytes[2] == 78 &&
          bytes[3] == 71;
      final webp =
          bytes.length >= 12 &&
          String.fromCharCodes(bytes.take(4)) == 'RIFF' &&
          String.fromCharCodes(bytes.skip(8).take(4)) == 'WEBP';
      if (!jpg && !png && !webp) {
        throw AuthException('Choose a JPG, PNG or WebP photo.');
      }
      return ProfilePhoto(
        bytes,
        jpg
            ? 'profile.jpg'
            : png
            ? 'profile.png'
            : 'profile.webp',
      );
    } on PlatformException {
      throw AuthException(
        'Could not open your photos. Check photo access in Settings and try again.',
      );
    }
  }
}
