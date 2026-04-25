import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/models/document.dart';
import 'package:docsera/screens/home/Document/document_info_screen.dart';
import 'package:docsera/services/encryption/message_encryption_service.dart';
import 'package:docsera/services/supabase/storage_quota_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../utils/full_page_loader.dart';
import 'document_options_bottom_sheet.dart';

class DocumentPreviewPage extends StatefulWidget {
  final UserDocument document;
  final bool cameFromConversation;
  final String? doctorName;
  final bool showActions;
  /// Optional: chat_media.id — if provided, `markChatMediaSaved` is called
  /// after the patient saves the PDF to their Documents vault.
  final String? chatMediaId;

  const DocumentPreviewPage({
    super.key,
    required this.document,
    this.cameFromConversation = false,
    this.doctorName,
    this.showActions = true,
    this.chatMediaId,
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
  /// Phase 2 (Patient File Hub): uses the document's own `bucket` so report
  /// attachments (chat.attachments) resolve correctly alongside patient
  /// uploads (documents).
  Future<String> _resolveUrl(String urlOrPath) async {
    final bucket = widget.document.bucket;
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
    // Storage path → create signed URL in the document's bucket
    try {
      return await Supabase.instance.client.storage
          .from(bucket)
          .createSignedUrl(urlOrPath, 3600);
    } catch (e) {
      debugPrint("❌ Failed to sign storage path (bucket=$bucket): $e");
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

        // Check actual file content (not Content-Type, which is unreliable
        // for encrypted uploads that arrive as application/octet-stream).
        final isPdfBytes = bytes.length >= 4 &&
            bytes[0] == 0x25 && bytes[1] == 0x50 &&
            bytes[2] == 0x44 && bytes[3] == 0x46; // %PDF
        if (!isPdfBytes) {
          debugPrint('❌ Not a real PDF (magic bytes check), switching to image mode');
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

  /// ✅ Task 15: Save PDF (already decrypted and stored in _localPdfFile) to Documents vault.
  Future<void> _savePdfToDocuments(BuildContext context) async {
    final local = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);

    // Re-use the already-downloaded (and decrypted) temp file if available,
    // otherwise attempt to download it again.
    File? fileToSave = _localPdfFile;

    if (fileToSave == null || !fileToSave.existsSync()) {
      try {
        final firstPage = widget.document.pages.isNotEmpty
            ? widget.document.pages.first
            : widget.document.previewUrl;
        fileToSave = await _downloadPdf(firstPage);
      } catch (_) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(local.downloadFailed),
            backgroundColor: AppColors.red.withOpacity(0.9),
          ),
        );
        return;
      }
    }

    // Copy to a stable temp path with the document name so DocumentInfoScreen
    // gets a readable file name.
    final dir = await getTemporaryDirectory();
    final safeDocName = widget.document.name.endsWith('.pdf')
        ? widget.document.name
        : '${widget.document.name}.pdf';
    final destFile = File('${dir.path}/$safeDocName');
    if (fileToSave.path != destFile.path) {
      await fileToSave.copy(destFile.path);
    }

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentInfoScreen(
          images: [destFile.path],
          initialName: widget.document.name,
          cameFromMultiPage: false,
          pageCount: 1,
          initialPatientId: widget.document.patientId,
          cameFromConversation: true,
          conversationDoctorName: widget.doctorName ?? widget.document.conversationDoctorName,
        ),
      ),
    );

    // After returning from DocumentInfoScreen, mark the media as saved if we have an ID.
    if (widget.chatMediaId != null && widget.chatMediaId!.isNotEmpty) {
      try {
        await StorageQuotaService().markChatMediaSaved(widget.chatMediaId!);
      } catch (_) {
        // Non-critical — ignore silently.
      }
    }
  }

  /// Show bottom sheet with "Save" and "Add to Documents" for chat files.
  void _showChatFileOptionsSheet(BuildContext context) {
    final local = AppLocalizations.of(context)!;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSheetOption(
                context: ctx,
                icon: Icons.save_alt,
                title: local.save,
                onTap: () {
                  Navigator.pop(ctx);
                  _saveFileToDevice(context);
                },
              ),
              _buildSheetOption(
                context: ctx,
                icon: Icons.folder_outlined,
                title: local.addToDocuments,
                onTap: () {
                  Navigator.pop(ctx);
                  if (isPdf) {
                    _savePdfToDocuments(context);
                  } else {
                    _saveImagesToDocuments(context);
                  }
                },
              ),
              SizedBox(height: 12.h),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSheetOption({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        ListTile(
          dense: true,
          minVerticalPadding: 0,
          contentPadding: EdgeInsets.zero,
          horizontalTitleGap: 8.w,
          leading: Icon(icon, color: AppColors.main, size: 18.sp),
          title: Text(
            title,
            style: AppTextStyles.getText3(context).copyWith(
              color: AppColors.main,
              fontWeight: FontWeight.bold,
            ),
          ),
          onTap: onTap,
        ),
        Divider(height: 1.h, color: Colors.grey[300]),
      ],
    );
  }

  /// Save the file to device — images to gallery, PDFs via share sheet.
  Future<void> _saveFileToDevice(BuildContext context) async {
    final local = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);

    try {
      if (isPdf) {
        File? file = _localPdfFile;
        if (file == null || !file.existsSync()) {
          final firstPage = widget.document.pages.isNotEmpty
              ? widget.document.pages.first
              : widget.document.previewUrl;
          file = await _downloadPdf(firstPage);
        }
        final box = context.findRenderObject() as RenderBox?;
        final origin = box != null
            ? (box.localToGlobal(Offset.zero) & box.size)
            : Rect.fromCenter(
                center: Offset(
                  MediaQuery.of(context).size.width / 2,
                  MediaQuery.of(context).size.height / 2,
                ),
                width: 1,
                height: 1,
              );
        await Share.shareXFiles([XFile(file.path)], sharePositionOrigin: origin);
      } else {
        // Save images to gallery
        for (int i = 0; i < _imageBytes.length; i++) {
          if (_imageBytes[i].isEmpty) continue;
          final dir = await getTemporaryDirectory();
          final ext = widget.document.pages[i].toLowerCase().endsWith('.png') ? 'png' : 'jpg';
          final file = File('${dir.path}/chat_image_$i.$ext');
          await file.writeAsBytes(_imageBytes[i]);
          await GallerySaver.saveImage(file.path);
        }
        if (context.mounted) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(local.downloadCompleted),
              backgroundColor: AppColors.main.withValues(alpha: 0.8),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Save failed: $e');
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(local.downloadFailed),
            backgroundColor: AppColors.red.withValues(alpha: 0.8),
          ),
        );
      }
    }
  }

  /// Save chat images to Documents vault.
  Future<void> _saveImagesToDocuments(BuildContext context) async {
    final local = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);

    try {
      final dir = await getTemporaryDirectory();
      final List<String> paths = [];
      for (int i = 0; i < _imageBytes.length; i++) {
        if (_imageBytes[i].isEmpty) continue;
        final ext = widget.document.pages[i].toLowerCase().endsWith('.png') ? 'png' : 'jpg';
        final file = File('${dir.path}/chat_img_${i}_${DateTime.now().millisecondsSinceEpoch}.$ext');
        await file.writeAsBytes(_imageBytes[i]);
        paths.add(file.path);
      }

      if (paths.isEmpty || !mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DocumentInfoScreen(
            images: paths,
            initialName: local.imageFromDoctor(widget.doctorName ?? local.doctor),
            cameFromMultiPage: paths.length > 1,
            pageCount: paths.length,
            initialPatientId: widget.document.patientId,
            cameFromConversation: true,
            conversationDoctorName: widget.doctorName ?? widget.document.conversationDoctorName,
          ),
        ),
      );

      if (widget.chatMediaId != null && widget.chatMediaId!.isNotEmpty) {
        try {
          await StorageQuotaService().markChatMediaSaved(widget.chatMediaId!);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('❌ Save images to documents failed: $e');
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(local.uploadFailed),
            backgroundColor: AppColors.red.withValues(alpha: 0.8),
          ),
        );
      }
    }
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
            if (widget.cameFromConversation)
              IconButton(
                tooltip: AppLocalizations.of(context)!.download,
                icon: const Icon(Icons.save_alt, color: Colors.white),
                onPressed: () => _showChatFileOptionsSheet(context),
              )
            else
              IconButton(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onPressed: () {
                  showDocumentOptionsSheet(context, widget.document);
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
