import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class ChatImageCompressor {
  /// ضغط مجموعة صور مع الحفاظ على الجودة المقبولة
  Future<List<File>> compress(List<File> files) async {
    List<File> results = [];

    for (final file in files) {
      final originalSize = await file.length();

      if (originalSize <= 200 * 1024) {
        results.add(file);
        continue;
      }

      int quality = 50;
      if (originalSize <= 500 * 1024) {
        quality = 75;
      } else if (originalSize <= 1 * 1024 * 1024) quality = 50;
      else if (originalSize <= 2 * 1024 * 1024) quality = 35;
      else quality = 25;

      final target = '${file.path}_compressed.jpg';
      final compressed = await FlutterImageCompress.compressAndGetFile(
        file.path,
        target,
        quality: quality,
        keepExif: true,
        format: CompressFormat.jpeg,
      );

      if (compressed == null) {
        results.add(file);
        continue;
      }

      final compressedSize = await compressed.length();
      if (compressedSize > originalSize) {
        results.add(file);
      } else {
        results.add(File(compressed.path));
      }
    }

    return results;
  }
}
