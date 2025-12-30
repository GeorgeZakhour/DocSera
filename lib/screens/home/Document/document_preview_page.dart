import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/models/document.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import '../../../utils/full_page_loader.dart';
import 'document_options_bottom_sheet.dart';

class DocumentPreviewPage extends StatefulWidget {
  final UserDocument document;
  final bool cameFromConversation;
  final String? doctorName;

  const DocumentPreviewPage({
    Key? key,
    required this.document,
    this.cameFromConversation = false,
    this.doctorName,
  }) : super(key: key);

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

  @override
  void initState() {
    super.initState();
    final firstUrl = widget.document.pages.isNotEmpty
        ? widget.document.pages.first
        : widget.document.previewUrl;

    final filename = widget.document.pages.isNotEmpty
        ? path.basename(Uri.parse(widget.document.pages.first).path).toLowerCase()
        : path.basename(Uri.parse(widget.document.previewUrl).path).toLowerCase();

    print('🔍 fileType: ${widget.document.fileType}');
    print('📂 filename: $filename');
    print('📄 pages count: ${widget.document.pages.length}');
    print('📃 is from conversation: ${widget.cameFromConversation}');

    final hasMultipleImagePages = widget.document.pages.length >= 1 &&
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

    print('🖼 hasMultipleImagePages: $hasMultipleImagePages');
    print('🖼 isImageMasqueradingAsPdf: $isImageMasqueradingAsPdf');

    isImage = widget.document.fileType == 'image' || hasMultipleImagePages || isImageMasqueradingAsPdf;
    isPdf = widget.document.fileType == 'pdf' &&
        !hasMultipleImagePages &&
        !isImageMasqueradingAsPdf &&
        filename.endsWith('.pdf');

    print('✅ Final type -> isImage: $isImage | isPdf: $isPdf');

    if (isPdf) {
      _downloadPdfFromUrl(firstUrl, widget.document.name).then((file) {
        if (mounted) {
          setState(() {
            _localPdfFile = file;
            _loading = false;
          });
        }
      }).catchError((e) {
        print('❌ Failed to download PDF: $e');
        setState(() {
          _loading = false;
          _localPdfFile = null;
        });
      });
    } else if (isImage) {
      print('📥 Preloading images...');
      _preloadImages();
    }
  }





  void _preloadImages() async {
    print('_preloadImages Activated!');
    final urls = widget.document.pages;
    final List<Uint8List> loaded = [];

    for (int i = 0; i < urls.length; i++) {
      try {
        final res = await http.get(Uri.parse(urls[i]));
        loaded.add(res.statusCode == 200 ? res.bodyBytes : Uint8List(0));
      } catch (_) {
        loaded.add(Uint8List(0));
      }
      setState(() => _progress = (i + 1) / urls.length);
    }

    setState(() {
      _imageBytes = loaded;
      _imagesLoaded = true;
    });
  }

  Future<File> _downloadPdfFromUrl(String url, String fileName) async {
    try {
      final response = await http.get(Uri.parse(url));
      final contentType = response.headers['content-type'];
      print('📦 Content-Type: $contentType');

      if (response.statusCode == 200) {
        final dir = await getTemporaryDirectory();
        final extension = path.extension(Uri.parse(url).path);
        final safeFileName = fileName.endsWith(extension) ? fileName : '$fileName$extension';
        final file = File('${dir.path}/$safeFileName');
        await file.writeAsBytes(response.bodyBytes, flush: true);
        print('✅ File saved at: ${file.path}');

        // ✅ Check actual file type
        if (contentType != null && !contentType.contains('pdf')) {
          print('❌ Not a real PDF, switching to image mode');
          setState(() {
            isPdf = false;
            isImage = true;
          });

          // ✅ تحميل الصورة الآن
          _preloadImages();
        }


        return file;
      } else {
        throw Exception('Failed to load file. Status: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error downloading file: $e');
      rethrow;
    }
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
          actions: [
            IconButton(
              icon: Icon(Icons.more_vert, color: Colors.white),
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
          ],
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
          return Center(child: Text('❌ نوع غير مدعوم', style: TextStyle(color: Colors.red)));
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
          onViewCreated: (controller) => print('✅ PDF view created'),
          onError: (error) => print('❌ PDF view error: $error'),
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
                      child: Icon(Icons.broken_image, size: 80, color: Colors.grey),
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
