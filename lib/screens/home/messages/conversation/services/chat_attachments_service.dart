import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatAttachmentsService {
  ChatAttachmentsService(this._client);

  final SupabaseClient _client;

  /// Cache للـ signed URLs
  final Map<String, String> _signedUrlCache = {};

  /// توليد URL يدعم public و private
  Future<String> getFileUrl({
    required String bucket,
    required String filePath,
  }) async {
    final key = '$bucket::$filePath';

    if (_signedUrlCache.containsKey(key)) {
      return _signedUrlCache[key]!;
    }

    final storage = _client.storage.from(bucket);

    try {
      final signed = await storage.createSignedUrl(filePath, 60 * 60 * 24 * 7);
      _signedUrlCache[key] = signed;
      return signed;
    } catch (_) {
      final publicUrl = storage.getPublicUrl(filePath);
      _signedUrlCache[key] = publicUrl;
      return publicUrl;
    }
  }

  Future<List<String>> resolveImageUrls(List<Map<String, dynamic>> images) async {
    final List<String> urls = [];

    for (final img in images) {
      final direct = img["file_url"] ?? img["fileUrl"];
      if (direct is String && direct.trim().isNotEmpty) {
        urls.add(direct.trim());
        continue;
      }

      final bucket = (img["bucket"] ?? "chat.attachments").toString();
      final paths = (img["paths"] as List?) ?? [];
      if (paths.isEmpty) continue;

      final pathStr = paths.first.toString();
      final url = await getFileUrl(bucket: bucket, filePath: pathStr);
      urls.add(url);
    }

    return urls;
  }

  /// Sanitization لاسم الملف (يدعم العربية)
  String sanitizeFileName(String input) {
    final normalized = input
        .replaceAll('ß', 'ss')
        .replaceAllMapped(RegExp(r'([^\u0000-\u007F])'),
            (match) => _removeDiacriticChar(match.group(0)!));

    final cleaned = normalized
        .replaceAll(RegExp(r'[^\w\s.-]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();

    return cleaned.isEmpty ? 'document' : cleaned;
  }

  String _removeDiacriticChar(String char) {
    final bytes = utf8.encode(char);
    final decoded = utf8.decode(bytes, allowMalformed: true);
    return decoded.replaceAll(RegExp(r'[\u0300-\u036f]'), '');
  }

  /// تحميل ملف إلى الجهاز (للسيف أو addToDocument)
  Future<String> downloadToLocal(String url) async {
    final resp = await http.get(Uri.parse(url));
    final temp = await getTemporaryDirectory();
    final name = path.basename(url);
    final file = File('${temp.path}/$name');
    await file.writeAsBytes(resp.bodyBytes);
    return file.path;
  }
}
