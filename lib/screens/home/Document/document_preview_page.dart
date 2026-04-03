import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/models/document.dart';
import 'package:docsera/services/encryption/message_encryption_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../utils/full_page_loader.dart';
import 'document_options_bottom_sheet.dart';

class DocumentPreviewPage extends StatefulWidget {
  final UserDocument document;
  final bool cameFromConversation;
  final String? doctorName;
  final bool showActions;

  const DocumentPreviewPage({
    super.key,
    required this.document,
    this.cameFromConversation = false,
    this.doctorName,
    this.showActions = true,
  });

  @override
  State<DocumentPreviewPage> createState() => _DocumentPreviewPageState();
}

class _DocumentPreviewPageState extends State<DocumentPreviewPage> {
  final TransformationController _transformationController = TransformationController();
  final ScrollController _scrollController = ScrollController();
  TapDownDetails? _doubleTapDetails;
  bool _imagesLoaded = false;
  List<Uint8List> _imageBytes = [];
  double _progress = 0.0;
  bool _loading = true;
  File? _localPdfFile;
  int _totalPages = 0;
  int _currentPage = 0;
  late bool isPdf;
  late bool isImage;

  /// ✅ Phase 2B: Resolve a page URL/path to a signed URL if it's a storage path
  Future<String> _resolveUrl(String urlOrPath) async {
    if (urlOrPath.startsWith('http://') || urlOrPath.startsWith('https://')) {
      // Legacy full URL — check if it's a public URL that needs signing
      if (urlOrPath.contains('/storage/v1/object/public/documents/')) {
        try {
          final rawPath = urlOrPath.split('/documents/').last;
          final storagePath = Uri.decodeComponent(rawPath);
          return await Supabase.instance.client.storage
              .from('documents')
              .createSignedUrl(storagePath, 3600);
        } catch (_) {
          return urlOrPath; // Fallback to original URL
        }
      }
      return urlOrPath;
    }
    // Storage path → create signed URL
    try {
      return await Supabase.instance.client.storage
          .from('documents')
          .createSignedUrl(urlOrPath, 3600);
    } catch (e) {
      debugPrint("❌ Failed to sign storage path: $e");
      return '';
    }
  }

  @override
  void initState() {
    super.initState();
    final firstPage = widget.document.pages.isNotEmpty
        ? widget.document.pages.first
        : widget.document.previewUrl;

    // For file type detection, use the original path/URL before resolution
    final filename = widget.document.pages.isNotEmpty
        ? path.basename(Uri.parse(widget.document.pages.first).path).toLowerCase()
        : path.basename(Uri.parse(widget.document.previewUrl).path).toLowerCase();

    debugPrint('🔍 fileType: ${widget.document.fileType}');
    debugPrint('📂 filename: $filename');
    debugPrint('📄 pages count: ${widget.document.pages.length}');
    debugPrint('📃 is from conversation: ${widget.cameFromConversation}');
    debugPrint('🔒 encrypted: ${widget.document.encrypted}');

    final hasMultipleImagePages = widget.document.pages.isNotEmpty &&
        widget.document.pages.every((url) =>
        url.toLowerCase().endsWith('.jpg') ||
            url.toLowerCase().endsWith('.jpeg') ||
            url.toLowerCase().endsWith('.png') ||
            url.toLowerCase().endsWith('.webp'));

    final isImageMasqueradingAsPdf = widget.document.fileType == 'pdf' &&
        widget.document.pages.length == 1 &&
        (filename.endsWith('.jpg') ||
            filename.endsWith('.jpeg') ||
            filename.endsWith('.png') ||
            filename.endsWith('.webp'));

    debugPrint('🖼 hasMultipleImagePages: $hasMultipleImagePages');
    debugPrint('🖼 isImageMasqueradingAsPdf: $isImageMasqueradingAsPdf');

    isImage = widget.document.fileType == 'image' || hasMultipleImagePages || isImageMasqueradingAsPdf;
    isPdf = widget.document.fileType == 'pdf' &&
        !hasMultipleImagePages &&
        !isImageMasqueradingAsPdf &&
        filename.endsWith('.pdf');

    debugPrint('✅ Final type -> isImage: $isImage | isPdf: $isPdf');

    if (isPdf) {
      if (!firstPage.startsWith('http') && File(firstPage).existsSync()) {
        debugPrint('📂 Opening local PDF file: $firstPage');
        setState(() {
          _localPdfFile = File(firstPage);
          _loading = false;
        });
      } else {
        _downloadPdf(firstPage).then((file) {
          if (mounted) {
            setState(() {
              _localPdfFile = file;
              _loading = false;
            });
          }
        }).catchError((e) {
          debugPrint('❌ Failed to download PDF: $e');
          setState(() {
            _loading = false;
            _localPdfFile = null;
          });
        });
      }
    } else if (isImage) {
      debugPrint('📥 Preloading images...');
      _preloadImages();
    }
  }

  /// ✅ Phase 2B+2C: Download PDF with signed URL + decrypt if needed
  Future<File> _downloadPdf(String urlOrPath) async {
    final url = await _resolveUrl(urlOrPath);
    if (url.isEmpty) throw Exception("Could not resolve PDF URL");

    try {
      final response = await http.get(Uri.parse(url));
      final contentType = response.headers['content-type'];
      debugPrint('📦 Content-Type: $contentType');

      if (response.statusCode == 200) {
        var bytes = response.bodyBytes;

        // ✅ Phase 2C: Decrypt if encrypted
        if (widget.document.encrypted) {
          final enc = MessageEncryptionService.instance;
          await enc.ensureReady();
          if (enc.isReady) {
            final decrypted = enc.decryptBytes(Uint8List.fromList(bytes));
            if (decrypted != null) bytes = decrypted;
          }
        }

        final dir = await getTemporaryDirectory();
        final extension = path.extension(Uri.parse(url).path);
        final safeFileName = widget.document.name.endsWith(extension)
            ? widget.document.name
            : '${widget.document.name}$extension';
        final file = File('${dir.path}/$safeFileName');
        await file.writeAsBytes(bytes, flush: true);
        debugPrint('✅ File saved at: ${file.path}');

        // Check actual file type
        if (contentType != null && !contentType.contains('pdf')) {
          debugPrint('❌ Not a real PDF, switching to image mode');
          setState(() {
            isPdf = false;
            isImage = true;
          });
          _preloadImages();
        }

        return file;
      } else {
        throw Exception('Failed to load file. Status: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error downloading file: $e');
      rethrow;
    }
  }

  /// ✅ Phase 2B+2C: Preload images with signed URL resolution + decryption
  void _preloadImages() async {
    debugPrint('_preloadImages Activated!');
    final pages = widget.document.pages;
    final List<Uint8List> loaded = [];

    for (int i = 0; i < pages.length; i++) {
      try {
        final pageRef = pages[i];
        if (!pageRef.startsWith('http') && File(pageRef).existsSync()) {
          loaded.add(await File(pageRef).readAsBytes());
        } else {
          final url = await _resolveUrl(pageRef);
          if (url.isEmpty) {
            loaded.add(Uint8List(0));
            continue;
          }
          final res = await http.get(Uri.parse(url));
          if (res.statusCode == 200) {
            var bytes = res.bodyBytes;

            // ✅ Phase 2C: Decrypt if encrypted
            if (widget.document.encrypted) {
              final enc = MessageEncryptionService.instance;
              await enc.ensureReady();
              if (enc.isReady) {
                final decrypted = enc.decryptBytes(Uint8List.fromList(bytes));
                if (decrypted != null) bytes = decrypted;
              }
            }
            loaded.add(Uint8List.fromList(bytes));
          } else {
            loaded.add(Uint8List(0));
          }
        }
      } catch (_) {
        loaded.add(Uint8List(0));
      }
      setState(() => _progress = (i + 1) / pages.length);
    }

    setState(() {
      _imageBytes = loaded;
      _imagesLoaded = true;
    });
  }

  void _handleDoubleTap() {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    final pos = _doubleTapDetails!.localPosition;
    final zoom = scale == 1.0 ? 2.5 : 1.0;

    final matrix = Matrix4.identity()
      ..translate(-pos.dx * (zoom - 1), -pos.dy * (zoom - 1))
      ..scale(zoom);

    setState(() {
      _transformationController.value = scale == 1.0 ? matrix : Matrix4.identity();
    });
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(56.h),
        child: AppBar(
          backgroundColor: AppColors.main,
          elevation: 0.5,
          title: Text(widget.document.name,
              style: AppTextStyles.getText2(context).copyWith(color: AppColors.whiteText)),
          centerTitle: true,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 14.sp),
            onPressed: () => Navigator.pop(context),
          ),
          actions: widget.showActions ? [
            IconButton(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onPressed: () {
                final fromConversationButNotSaved =
                    widget.cameFromConversation && !widget.document.id!.startsWith('doc_');

                if (fromConversationButNotSaved) {
                  showConversationPdfOptionsSheet(
                    context,
                    widget.document,
                    widget.document.patientId,
                    widget.doctorName ?? '',
                  );
                } else {
                  showDocumentOptionsSheet(context, widget.document);
                }
              },
            ),
          ] : null,
          bottom: widget.document.fileType != 'pdf' && !_imagesLoaded
              ? PreferredSize(
            preferredSize: Size.fromHeight(4.h),
            child: LinearProgressIndicator(
              value: _progress,
              backgroundColor: AppColors.main.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation(AppColors.whiteText.withOpacity(0.5)),
              minHeight: 4.h,
            ),
          )
              : null,
        ),
      ),
      body: Builder(
        builder: (context) {
          if (isPdf) return _buildPdfViewer();
          if (isImage) return _imagesLoaded ? _buildImageViewer() : const Center(child: FullPageLoader());
          return const Center(child: Text('❌ نوع غير مدعوم', style: TextStyle(color: Colors.red)));
        },
      ),
    );
  }

  Widget _buildPdfViewer() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.main));
    } else if (_localPdfFile == null) {
      return Center(child: Text(AppLocalizations.of(context)!.fileLoadFailed));
    } else {
      return Container(
        color: Colors.white,
        child: PDFView(
          filePath: _localPdfFile!.path,
          enableSwipe: true,
          swipeHorizontal: false,
          autoSpacing: false,
          pageSnap: true,
          backgroundColor: Colors.grey.withOpacity(0.2),
          fitPolicy: FitPolicy.BOTH,
          onRender: (pages) => setState(() => _totalPages = pages ?? 0),
          onPageChanged: (page, _) => setState(() => _currentPage = page ?? 0),
          onViewCreated: (controller) => debugPrint('✅ PDF view created'),
          onError: (error) => debugPrint('❌ PDF view error: $error'),
        )
      );
    }
  }

  Widget _buildImageViewer() {
    return GestureDetector(
      onDoubleTapDown: (details) => _doubleTapDetails = details,
      onDoubleTap: _handleDoubleTap,
      child: InteractiveViewer(
        transformationController: _transformationController,
        panEnabled: true,
        scaleEnabled: true,
        minScale: 1.0,
        maxScale: 4.0,
        child: SingleChildScrollView(
          controller: _scrollController,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height, // ✅ لضمان الطول الأدنى
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _imageBytes.map((bytes) {
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12.r),
                    child: bytes.isNotEmpty
                        ? Image.memory(
                      bytes,
                      fit: BoxFit.contain,
                    )
                        : Container(
                      height: 200.h,
                      color: Colors.grey[200],
                      child: const Icon(Icons.broken_image, size: 80, color: Colors.grey),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}
