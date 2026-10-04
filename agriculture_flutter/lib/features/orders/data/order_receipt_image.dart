import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../auth/data/services/profile_photo.dart';
import 'purchase_service.dart';

/// Preserve the original receipt so transaction details remain readable.
Future<ProfilePhoto?> pickOrderReceipt() async {
  try {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      requestFullMetadata: false,
    );
    if (file == null) return null;
    if (await file.length() > 5 * 1024 * 1024) {
      throw const PurchaseException('Choose a receipt image up to 5 MB.');
    }
    return validateOrderReceipt(await file.readAsBytes());
  } on PlatformException {
    throw const PurchaseException(
      'Could not open your photos. Check photo access in Settings and try again.',
    );
  }
}

ProfilePhoto validateOrderReceipt(Uint8List bytes) {
  if (bytes.length < 12 || bytes.length > 5 * 1024 * 1024) {
    throw const PurchaseException('Choose a receipt image up to 5 MB.');
  }
  final png = const [137, 80, 78, 71, 13, 10, 26, 10];
  final isPng = List.generate(8, (i) => bytes[i] == png[i]).every((v) => v);
  final isJpg = bytes[0] == 255 && bytes[1] == 216 && bytes[2] == 255;
  final isWebp =
      String.fromCharCodes(bytes.take(4)) == 'RIFF' &&
      String.fromCharCodes(bytes.skip(8).take(4)) == 'WEBP';
  if (!isPng && !isJpg && !isWebp) {
    throw const PurchaseException('Use a JPG, PNG or WebP receipt.');
  }
  return ProfilePhoto(
    bytes,
    'receipt.${isPng
        ? 'png'
        : isJpg
        ? 'jpg'
        : 'webp'}',
  );
}
