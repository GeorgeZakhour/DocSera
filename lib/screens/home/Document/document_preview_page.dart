import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/models/document.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/app/const.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'document_options_bottom_sheet.dart';

class DocumentPreviewPage extends StatefulWidget {
  final UserDocument document;
  const DocumentPreviewPage({Key? key, required this.document}) : super(key: key);

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
    final firstUrl = widget.document.pages.first;
    final filename = path.basename(Uri.parse(firstUrl).path).toLowerCase();

    isPdf = widget.document.type == 'pdf' || filename.endsWith('.pdf');
    isImage = widget.document.type == 'image' ||
        filename.endsWith('.jpg') ||
        filename.endsWith('.jpeg') ||
        filename.endsWith('.png') ||
        filename.endsWith('.webp');

    if (isImage) {
      _preloadImages();
    } else if (isPdf) {
      _downloadAndCachePdf(firstUrl);
    }
  }

  void _preloadImages() async {
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

  Future<void> _downloadAndCachePdf(String url) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/${widget.document.id}.pdf');
      if (await file.exists()) {
        print('📦 Loaded from cache: ${file.path}');
      } else {
        print('⬇️ Downloading PDF...');
        final response = await http.get(Uri.parse(url));
        await file.writeAsBytes(response.bodyBytes);
      }
      setState(() {
        _localPdfFile = file;
        _loading = false;
      });
    } catch (e) {
      print('❌ Failed to download PDF: $e');
      setState(() => _loading = false);
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
    final locale = AppLocalizations.of(context)!;

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
              onPressed: () => showDocumentOptionsSheet(context, widget.document),
            ),
          ],
          bottom: widget.document.type != 'pdf' && !_imagesLoaded
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
          if (isImage) return _imagesLoaded ? _buildImageViewer() : const Center(child: CircularProgressIndicator(color: AppColors.main));
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
        ),
      );
    }
  }

  Widget _buildImageViewer() {
    return ScrollbarTheme(
      data: ScrollbarThemeData(
        thumbColor: MaterialStateProperty.all(Colors.black.withOpacity(0.08)),
        thickness: MaterialStateProperty.all(3),
        radius: Radius.circular(5),
      ),
      child: Scrollbar(
        controller: _scrollController,
        interactive: true,
        thumbVisibility: false,
        scrollbarOrientation: ScrollbarOrientation.right,
        child: GestureDetector(
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
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _imageBytes.map((bytes) {
                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 4.h),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12.r),
                      child: bytes.isNotEmpty
                          ? Image.memory(bytes, fit: BoxFit.contain, width: double.infinity)
                          : Icon(Icons.broken_image, size: 80, color: Colors.grey),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
