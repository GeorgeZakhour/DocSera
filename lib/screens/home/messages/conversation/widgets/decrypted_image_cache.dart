import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:docsera/services/encryption/message_encryption_service.dart';

/// ============================================================
/// Decrypted Image Cache (DocSera Patient App)
/// ============================================================
/// Singleton in-memory cache for decrypted image bytes.
/// Prevents re-downloading and re-decrypting on every rebuild.
/// ============================================================

class DecryptedImageCache {
  DecryptedImageCache._();
  static final instance = DecryptedImageCache._();

  final Map<String, Uint8List> _cache = {};
  final Map<String, Future<Uint8List?>> _pending = {};
  final Map<String, String> _signedUrlCache = {};

  /// Get or load decrypted bytes for a given cache key
  Future<Uint8List?> getOrLoad({
    required String cacheKey,
    required Future<String?> Function() urlResolver,
    required bool encrypted,
  }) async {
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;
    if (_pending.containsKey(cacheKey)) return _pending[cacheKey];

    final future = _download(urlResolver, encrypted);
    _pending[cacheKey] = future;

    final result = await future;
    _pending.remove(cacheKey);

    if (result != null) _cache[cacheKey] = result;
    return result;
  }

  /// Check cache synchronously (instant render)
  Uint8List? getCached(String cacheKey) => _cache[cacheKey];

  /// Get or create a signed URL (cached)
  Future<String> getSignedUrl(String bucket, String path) async {
    final key = '$bucket::$path';
    if (_signedUrlCache.containsKey(key)) return _signedUrlCache[key]!;

    final signed = await Supabase.instance.client.storage
        .from(bucket)
        .createSignedUrl(path, 60 * 60 * 24 * 7);
    _signedUrlCache[key] = signed;
    return signed;
  }

  Future<Uint8List?> _download(
    Future<String?> Function() urlResolver,
    bool encrypted,
  ) async {
    try {
      final url = await urlResolver();
      if (url == null || url.isEmpty) return null;

      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode != 200) return null;

      var bytes = Uint8List.fromList(resp.bodyBytes);

      if (encrypted) {
        final enc = MessageEncryptionService.instance;
        await enc.ensureReady(); // ✅ Defensive: ensure key is loaded
        if (enc.isReady) {
          final decrypted = enc.decryptBytes(bytes);
          if (decrypted != null) bytes = decrypted;
        }
      }
      return bytes;
    } catch (_) {
      return null;
    }
  }

  void clear() {
    _cache.clear();
    _signedUrlCache.clear();
  }
}

// ============================================================
// Shimmer placeholder
// ============================================================

class ImageShimmer extends StatelessWidget {
  const ImageShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8.r),
        ),
      ),
    );
  }
}

// ============================================================
// Widget: Smart image tile for chat attachments
// Works with raw Map<String, dynamic> attachment data
// ============================================================

class CachedChatImage extends StatefulWidget {
  /// Raw attachment map: {type, bucket, paths, encrypted, localPath, file_url, ...}
  final Map<String, dynamic> attachment;
  final BoxFit fit;

  const CachedChatImage({
    super.key,
    required this.attachment,
    this.fit = BoxFit.cover,
  });

  @override
  State<CachedChatImage> createState() => _CachedChatImageState();
}

class _CachedChatImageState extends State<CachedChatImage>
    with AutomaticKeepAliveClientMixin {
  Uint8List? _bytes;
  String? _displayUrl; // For legacy unencrypted images
  bool _loading = true;
  bool _error = false;

  @override
  bool get wantKeepAlive => true;

  bool get _isEncrypted => widget.attachment['encrypted'] == true;

  bool get _isLocal {
    final lp = widget.attachment['localPath']?.toString() ?? '';
    return lp.startsWith('/') || lp.startsWith('file:');
  }

  String get _cacheKey {
    final bucket = (widget.attachment['bucket'] ?? 'chat.attachments').toString();
    final paths = (widget.attachment['paths'] as List?) ?? [];
    final path = paths.isNotEmpty ? paths.first.toString() : '';
    return '$bucket::$path';
  }

  @override
  void initState() {
    super.initState();

    // Priority 1: Local file path (optimistic UI — just sent)
    if (_isLocal) {
      _displayUrl = widget.attachment['localPath'].toString();
      _loading = false;
      return;
    }

    // Priority 2: Direct URL (legacy messages with file_url)
    final direct = widget.attachment['file_url'] ?? widget.attachment['fileUrl'];
    if (direct is String && direct.trim().isNotEmpty && !_isEncrypted) {
      _displayUrl = direct.trim();
      _loading = false;
      return;
    }

    // Priority 3: Encrypted → check cache for instant, else download+decrypt
    if (_isEncrypted) {
      final cached = DecryptedImageCache.instance.getCached(_cacheKey);
      if (cached != null) {
        _bytes = cached;
        _loading = false;
        return;
      }
      _loadEncrypted();
      return;
    }

    // Priority 4: Unencrypted with storage path → resolve signed URL
    _loadSignedUrl();
  }

  Future<void> _loadEncrypted() async {
    final cache = DecryptedImageCache.instance;
    final bucket = (widget.attachment['bucket'] ?? 'chat.attachments').toString();
    final paths = (widget.attachment['paths'] as List?) ?? [];

    if (paths.isEmpty) {
      if (mounted) setState(() { _loading = false; _error = true; });
      return;
    }

    final pathStr = paths.first.toString();
    final bytes = await cache.getOrLoad(
      cacheKey: _cacheKey,
      urlResolver: () => cache.getSignedUrl(bucket, pathStr),
      encrypted: true,
    );

    if (!mounted) return;
    setState(() {
      _bytes = bytes;
      _loading = false;
      _error = bytes == null;
    });
  }

  Future<void> _loadSignedUrl() async {
    try {
      final bucket = (widget.attachment['bucket'] ?? 'chat.attachments').toString();
      final paths = (widget.attachment['paths'] as List?) ?? [];

      if (paths.isEmpty) {
        if (mounted) setState(() { _loading = false; _error = true; });
        return;
      }

      final url = await DecryptedImageCache.instance.getSignedUrl(bucket, paths.first.toString());
      if (!mounted) return;
      setState(() {
        _displayUrl = url;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() { _loading = false; _error = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loading) return const ImageShimmer();

    if (_error) {
      return Container(
        color: Colors.grey[300],
        child: const Icon(Icons.broken_image, color: Colors.grey),
      );
    }

    // ✅ Encrypted → from memory
    if (_bytes != null) {
      return Image.memory(
        _bytes!,
        fit: widget.fit,
        errorBuilder: (_, __, ___) => Container(
          color: Colors.grey[300],
          child: const Icon(Icons.broken_image, color: Colors.grey),
        ),
      );
    }

    // ✅ Local file (optimistic UI)
    if (_displayUrl != null && (_displayUrl!.startsWith('/') || _displayUrl!.startsWith('file:'))) {
      return Image.file(
        File(_displayUrl!),
        fit: widget.fit,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded || frame != null) return child;
          return const ImageShimmer();
        },
        errorBuilder: (_, __, ___) => const Icon(Icons.error),
      );
    }

    // ✅ Network URL (legacy or signed)
    if (_displayUrl != null) {
      return CachedNetworkImage(
        imageUrl: _displayUrl!,
        fit: widget.fit,
        memCacheWidth: 500,
        maxWidthDiskCache: 1000,
        placeholder: (_, __) => const ImageShimmer(),
        imageBuilder: (context, imageProvider) => Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: imageProvider,
              fit: widget.fit,
            ),
          ),
        ),
        fadeInDuration: const Duration(milliseconds: 100),
        errorWidget: (_, __, ___) => const Icon(Icons.error),
      );
    }

    return const SizedBox();
  }
}
