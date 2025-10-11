import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:diacritic/diacritic.dart';
import 'package:docsera/models/document.dart';
import 'package:docsera/screens/home/Document/document_info_screen.dart';
import 'package:docsera/screens/home/Document/document_preview_page.dart';
import 'package:docsera/screens/home/shimmer/shimmer_widgets.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'package:docsera/widgets/custom_bottom_navigation_bar.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart' as intl;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:transparent_image/transparent_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:characters/characters.dart'; // ضيف هذا لو ما كان موجود
import 'dart:convert';

class PendingMessage {
  final String type; // 'image' أو 'pdf'
  final List<File> files;
  final DateTime createdAt;

  PendingMessage({required this.type, required this.files})
      : createdAt = DateTime.now();
}

class ConversationPage extends StatefulWidget {
  final String conversationId;
  final String doctorName;
  final String doctorSpecialty;
  final ImageProvider doctorImage;
  final bool isClosed;
  final String patientName;
  final String accountHolderName;
  final String selectedReason;
  final UserDocument? attachedDocument;
  final List<File>? selectedImageFiles;
  final String? pendingFileType;

  const ConversationPage({
    Key? key,
    required this.conversationId,
    required this.doctorName,
    required this.doctorSpecialty,
    required this.doctorImage,
    required this.isClosed,
    required this.patientName,
    required this.accountHolderName,
    required this.selectedReason,
    this.attachedDocument,
    this.selectedImageFiles,
    this.pendingFileType,
  }) : super(key: key);


  @override
  State<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends State<ConversationPage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final List<PendingMessage> _pendingMessages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<File> _selectedImageFiles = [];
  String? _pendingFileType;
  bool _showAllAttachments = false;
  bool _expandedImageOverlay = false;
  bool _showAsGrid = false;
  List<String> _expandedImageUrls = [];
  int _initialImageIndex = 0;
  bool _isDownloadingSingle = false;
  bool _isDownloadingAll = false;
  Map<String, ImageProvider> _imageCache = {};
  Offset _doubleTapPosition = Offset.zero;
  final TransformationController _transformationController = TransformationController();
  bool _isZoomed = false;
  bool _shouldAutoScroll = true;
  bool _showScrollToBottom = false;
  bool _isUserAtBottom = true;
  UserDocument? _attachedDocument;
  bool _showImageDownloadOptions = false;
  late final Stream<List<Map<String, dynamic>>> _messageStream;




  @override
  void initState() {
    super.initState();
    print('🟠 initState called');
    _messageStream = Supabase.instance.client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', widget.conversationId)
        .order('timestamp', ascending: true)
        .execute();

    _scrollController.addListener(_handleScroll);

    _attachedDocument = widget.attachedDocument;

    if (_attachedDocument != null) {
      final doc = _attachedDocument!;
      final type = doc.type;
      final fileType = doc.fileType;
      final preview = doc.previewUrl;

      print('🧪 Document Received in ConversationPage');
      print('📂 doc.type: $type');
      print('📂🔍 doc.fileType: $fileType');
      print('🌐 doc.previewUrl: $preview');
      print('🔍 parsed path: ${Uri.parse(preview).path}');

      print('✅ Will treat as PDF (forced because from document page)');
      _pendingFileType = 'pdf';
      _selectedImageFiles.clear();
      _selectedImageFiles.add(File('/tmp/${doc.name ?? 'document'}.pdf'));
    }

    if (widget.selectedImageFiles != null && widget.selectedImageFiles!.isNotEmpty) {
      _selectedImageFiles = widget.selectedImageFiles!;
      _pendingFileType = widget.pendingFileType;
    } else if (_attachedDocument != null) {
      // old logic for document
      final doc = _attachedDocument!;
      _pendingFileType = 'pdf';
      _selectedImageFiles = [File('/tmp/${doc.name ?? 'document'}.pdf')];
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if ((_selectedImageFiles.isNotEmpty || _attachedDocument != null) && !_pendingMessages.any((p) => p.files.isNotEmpty)) {
        _sendMessage();
      }
    });


    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(Duration(milliseconds: 500), () {
        if (_scrollController.hasClients) {
          final maxScroll = _scrollController.position.maxScrollExtent;
          print('📏 Max Scroll after delay: $maxScroll');
          _scrollController.jumpTo(maxScroll);
          print('📍 Jumped to bottom after delay');
        } else {
          print('❌ Still no clients after delay');
        }
      });
    });

  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    final threshold = 100;
    final atBottom = _scrollController.position.pixels >= _scrollController.position.maxScrollExtent - threshold;

    if (_isUserAtBottom != atBottom) {
      setState(() {
        _isUserAtBottom = atBottom;
        _showScrollToBottom = !atBottom;
      });
    }
  }

  void _showImageOverlayWithIndex(List<String> urls, int index) {
    setState(() {
      _expandedImageUrls = urls;
      _initialImageIndex = index;
      _expandedImageOverlay = true;
      for (final url in urls) {
        _preloadImage(url);
      }
    });
  }

  void _showImageOverlay(List<String> urls) {
    setState(() {
      _expandedImageOverlay = true;
      _expandedImageUrls = urls;
      for (final url in urls) {
        _preloadImage(url);
      }

    });
  }

  void _hideImageOverlay() {
    setState(() {
      _expandedImageOverlay = false;
      _expandedImageUrls = [];
      _shouldAutoScroll = false;
    });

    // إعادة التمرير بعد وقت بسيط
    Future.delayed(const Duration(milliseconds: 200), () {
      _shouldAutoScroll = true;
    });
  }

  Future<void> _markMessagesAsRead(List<Map<String, dynamic>> messages) async {
    final unreadMessages = messages.where((msg) =>
    msg['is_user'] == false &&
        msg['read_by_user'] != true &&
        msg['id'] != null).toList();

    if (unreadMessages.isNotEmpty) {
      await Future.wait(unreadMessages.map((msg) {
        return Supabase.instance.client
            .from('messages')
            .update({
          'read_by_user': true,
          'read_by_user_at': DateTime.now().toUtc().toIso8601String(),
        })
            .eq('id', msg['id']);
      }));

      await Supabase.instance.client
          .from('conversations')
          .update({
        'last_message_read_by_user': true,
        'unread_count_for_user': 0,
      })
          .eq('id', widget.conversationId);
    }
  }


  bool _isArabicText(String text) {
    return RegExp(r'[\u0600-\u06FF]').hasMatch(text);
  }

  String _getInitials(String name) {
    final isAr = _isArabicText(name);
    final parts = name.trim().split(' ');
    if (isAr) {
      final firstChar = parts.first.isNotEmpty ? parts.first[0] : '';
      return firstChar == 'ه' ? 'هـ' : firstChar;
    } else {
      final first = parts.isNotEmpty ? parts[0][0] : '';
      final second = parts.length > 1 ? parts[1][0] : '';
      return (first + second).toUpperCase();
    }
  }

  String _getDayLabel(DateTime date, String lang) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      return lang == 'ar' ? 'اليوم' : 'Today';
    } else if (messageDate == yesterday) {
      return lang == 'ar' ? 'أمس' : 'Yesterday';
    } else {
      return intl.DateFormat('d MMM', lang == 'ar' ? 'ar' : 'en').format(date);
    }
  }

  String _formatReadTime(DateTime? date, String lang) {
    if (date == null) return '';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      return intl.DateFormat('HH:mm', lang == 'ar' ? 'ar' : 'en').format(date);
    } else if (messageDate == yesterday) {
      final time = intl.DateFormat('HH:mm', lang == 'ar' ? 'ar' : 'en').format(date);
      return lang == 'ar' ? 'أمس الساعة $time' : 'Yesterday at $time';
    } else {
      return intl.DateFormat('d MMM • HH:mm', lang == 'ar' ? 'ar' : 'en').format(date);
    }
  }

  Future<void> _preloadImage(String url) async {
    if (_imageCache.containsKey(url)) return;

    final completer = Completer<ImageInfo>();
    final stream = CachedNetworkImageProvider(url).resolve(ImageConfiguration());
    final listener = ImageStreamListener((ImageInfo info, bool _) {
      completer.complete(info);
    });

    stream.addListener(listener);
    final imageInfo = await completer.future;
    final byteData = await imageInfo.image.toByteData(format: ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();

    if (mounted) {
      setState(() {
        _imageCache[url] = MemoryImage(bytes);
      });
    }
  }

  Future<List<File>> compressImages(List<File> imageFiles) async {
    int totalOriginalSize = 0;
    int totalCompressedSize = 0;
    List<File> compressedImages = [];

    for (final file in imageFiles) {
      final realFile = File(file.absolute.path);
      final int originalSize = await realFile.length();
      totalOriginalSize += originalSize;

      debugPrint("🖼️ Real image path: ${realFile.path}");
      debugPrint("📄 Real image size: ${(originalSize / 1024).toStringAsFixed(2)} KB");

      if (originalSize <= 200 * 1024) {
        debugPrint("📷 Skipped compression (small file)");
        totalCompressedSize += originalSize;
        compressedImages.add(realFile);
        continue;
      }

      int quality = 50;
      if (originalSize <= 500 * 1024) {
        quality = 75;
      } else if (originalSize <= 1000 * 1024) {
        quality = 50;
      } else if (originalSize <= 2000 * 1024) {
        quality = 35;
      } else {
        quality = 25; // fallback للصور الكبيرة
      }

      final targetPath = '${realFile.path}_compressed.jpg';

      final XFile? compressed = await FlutterImageCompress.compressAndGetFile(
        realFile.absolute.path,
        targetPath,
        quality: quality,
        keepExif: true,
        format: CompressFormat.jpeg,
      );

      if (compressed != null) {
        final File compressedFile = File(compressed.path);
        final int compressedSize = await compressedFile.length();

        final int maxAllowedSize = 2 * 1024 * 1024; // 2MB (or any threshold you want per image)

        if (compressedSize >= originalSize || compressedSize > maxAllowedSize) {
          debugPrint("📷 Compression skipped (inefficient or too big): original ${originalSize / 1024} KB, compressed ${compressedSize / 1024} KB");
          totalCompressedSize += originalSize;
          compressedImages.add(realFile);
        } else {
          debugPrint("📉 Compressed size: ${(compressedSize / 1024).toStringAsFixed(2)} KB");
          debugPrint("🗜️ Compression saved: ${(100 - (compressedSize / originalSize * 100)).toStringAsFixed(2)}%");
          totalCompressedSize += compressedSize;
          compressedImages.add(compressedFile);
        }
      } else {
        debugPrint("⚠️ Compression failed, using original");
        totalCompressedSize += originalSize;
        compressedImages.add(realFile);
      }
    }

    debugPrint("📦 Total original size: ${(totalOriginalSize / 1024).toStringAsFixed(2)} KB");
    debugPrint("📦 Total compressed size: ${(totalCompressedSize / 1024).toStringAsFixed(2)} KB");

    if (totalCompressedSize > 4 * 1024 * 1024) {
      throw Exception("💥 Document too large after compression: ${(totalCompressedSize / 1024).toStringAsFixed(2)} KB");
    }

    return compressedImages;
  }


  String _sanitizeFileName(String name) {
    // Normalization to NFD and remove combining marks
    final normalized = name
        .replaceAll('ß', 'ss')
        .replaceAllMapped(
      RegExp(r'([^\u0000-\u007F])'),
          (match) => _removeDiacriticChar(match.group(0)!),
    );

    final cleaned = normalized
        .replaceAll(RegExp(r'[^\w\s.-]'), '') // رموز غريبة
        .replaceAll(RegExp(r'\s+'), '_') // مسافات → _
        .trim();

    return cleaned.isEmpty ? 'document.pdf' : cleaned;
  }

  String _removeDiacriticChar(String input) {
    // تحويل utf8 → ascii إن أمكن
    final bytes = utf8.encode(input);
    final decoded = utf8.decode(bytes, allowMalformed: true);
    return decoded.replaceAll(RegExp(r'[\u0300-\u036f]'), '');
  }

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty && _selectedImageFiles.isEmpty && widget.attachedDocument == null) return;


    final supabase = Supabase.instance.client;
    final conversationId = widget.conversationId;
    final now = DateTime.now().toUtc(); // ✅ UTC ثابت


    // ✅ ضغط الصور إذا موجودة
    List<File> filesToUpload = [];
    if (_pendingFileType == 'image' && _selectedImageFiles.isNotEmpty) {
      try {
        filesToUpload = await compressImages(_selectedImageFiles);
      } catch (e) {
        print('❌ Compression failed or total size too big: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.fileTooLarge), backgroundColor: AppColors.red.withOpacity(0.9)),
        );
        return;
      }
    } else {
      filesToUpload = List.from(_selectedImageFiles);
    }

    // ✅ أضف إلى قائمة pending
    if (filesToUpload.isNotEmpty && _pendingFileType != null) {
      setState(() {
        _pendingMessages.add(PendingMessage(
          type: _pendingFileType!,
          files: List.from(filesToUpload),
        ));
      });
    }


    List<Map<String, dynamic>> attachments = [];

    // ✅ رفع ملف الوثيقة إذا موجود
    if (widget.attachedDocument != null) {
      try {
        final fileType = 'pdf';
        final pdfUrl = widget.attachedDocument!.pages.first;
        final uri = Uri.parse(pdfUrl);
        final rawName = widget.attachedDocument!.name ?? 'document.pdf';
        final sanitized = _sanitizeFileName(rawName);
        final storageFileName = 'doc_${now.millisecondsSinceEpoch}_$sanitized';

        final response = await http.get(uri);
        if (response.statusCode != 200) {
          print('❌ Failed to download file: ${response.statusCode}');
          return;
        }

        final bytes = response.bodyBytes;
        if (bytes.length > 1 * 1024 * 1024) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.fileTooLarge), backgroundColor: AppColors.red.withOpacity(0.9)),
          );
          return;
        }
        print('🧪 Original name: $rawName');
        print('✅ After sanitize: $sanitized');
        print('📦 Final upload key: $conversationId/$storageFileName');

        print('storageFileName is : $conversationId/$storageFileName'); // ✅ طباعة المفتاح النهائي

        final uploadResponse = await supabase.storage
            .from('chat.attachments')
            .uploadBinary('$conversationId/$storageFileName', bytes, fileOptions: FileOptions(cacheControl: '3600', upsert: true));
        final uploadedUrl = supabase.storage.from('chat.attachments').getPublicUrl('$conversationId/$storageFileName');

        attachments.add({
          'file_url': uploadedUrl,
          'file_name': storageFileName,
          'type': fileType,
        });

      } catch (e) {
        print("❌ Error during PDF attachment upload: $e");
      }
    }


    for (final file in filesToUpload) {
      final originalFileName = file.path.split('/').last;
      final sanitizedFileName = _sanitizeFileName(originalFileName);
      final storagePath = '$conversationId/$sanitizedFileName';

      final fileBytes = await file.readAsBytes();
      final uploadResponse = await supabase.storage
          .from('chat.attachments')
          .uploadBinary(storagePath, fileBytes, fileOptions: FileOptions(upsert: true));
      final fileUrl = supabase.storage.from('chat.attachments').getPublicUrl(storagePath);

      attachments.add({
        'fileUrl': fileUrl,
        'fileName': sanitizedFileName,
        'type': _pendingFileType,
      });
      setState(() {
        _pendingMessages.removeWhere((p) => p.files.contains(file));
      });
    }

    await supabase.from('messages').insert({
      'conversation_id': conversationId,
      'text': text,
      'is_user': true,
      'sender_name': widget.patientName,
      'timestamp': now.toIso8601String(),
      'read_by_doctor': false,
      'read_by_user': true,
      'read_by_doctor_at': null,
      'read_by_user_at': now.toIso8601String(),
      if (attachments.isNotEmpty) 'attachments': attachments,
    });

// ✅ الخطوة الثانية: تحديث المحادثة
    await supabase.from('conversations').update({
      'last_message': text.isNotEmpty
          ? text
          : _pendingFileType == 'pdf'
          ? '📄 ملف PDF'
          : '🖼️ صورة مرفقة',
      'last_sender_id': 'user',
      'updated_at': now.toIso8601String(),
      'last_message_read_by_user': true,
      'last_message_read_by_doctor': false,
    }).eq('id', conversationId);

// ✅ الخطوة الثالثة: نفذ ال-RPC لحاله (بدون تحط نتيجته بأي مكان)
    await supabase.rpc('increment_unread_for_doctor', params: {
      'conversation_id': conversationId,
    });



    setState(() {
      _controller.clear();
      _selectedImageFiles.clear();
      _pendingFileType = null;
      _pendingMessages.clear(); // ✅ إزالة الرسائل المؤقتة بعد الإرسال
      _attachedDocument = null; // ✅ إخفاء المرفق القادم من صفحة الوثائق
    });

    if (_scrollController.hasClients && _isUserAtBottom) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 50,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _showAttachmentOptions() {
    final local = AppLocalizations.of(context)!;
    final isLimitReached = _selectedImageFiles.length >= 8;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (_) {
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppLocalizations.of(context)!.chooseAttachmentType,
                style: AppTextStyles.getTitle1(context).copyWith(fontSize: 12.sp, color: AppColors.grayMain),
              ),
              SizedBox(height: 10.h),
              Divider(height: 1.h, color: Colors.grey[200]),
              SizedBox(height: 20.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildIconAction(
                    iconPath: 'assets/icons/camera.svg',
                    label: AppLocalizations.of(context)!.takePhoto,
                    onTap: isLimitReached
                        ? null
                        : () async {
                      Navigator.pop(context);
                      final picked = await ImagePicker().pickImage(source: ImageSource.camera);
                      if (picked != null) {
                        _prepareFilePreview(File(picked.path), 'image');
                      }
                    },
                  ),
                  _buildIconAction(
                    iconPath: 'assets/icons/gallery.svg',
                    label: AppLocalizations.of(context)!.chooseFromLibrary2,
                    onTap: isLimitReached
                        ? null
                        : () async {
                      Navigator.pop(context);
                      final remaining = 8 - _selectedImageFiles.length;
                      final result = await FilePicker.platform.pickFiles(
                        type: FileType.image,
                        allowMultiple: true,
                      );
                      if (result != null && result.files.isNotEmpty) {
                        final pickedFiles = result.files
                            .where((file) => file.path != null)
                            .map((file) => File(file.path!))
                            .toList();

                        final newFiles = pickedFiles.where((newFile) =>
                        !_selectedImageFiles.any((existing) => existing.path == newFile.path)).toList();

                        if (newFiles.length > remaining) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${AppLocalizations.of(context)!.maxImagesReached} ($remaining ${AppLocalizations.of(context)!.remaining})',
                              ),
                            ),
                          );
                          return;
                        }

                        _prepareMultipleFilePreviews(newFiles, 'image');
                      }
                    },
                  ),
                  _buildIconAction(
                    iconPath: 'assets/icons/file.svg',
                    label: AppLocalizations.of(context)!.chooseFile,
                    onTap: _selectedImageFiles.isNotEmpty
                        ? null
                        : () async {
                      Navigator.pop(context);
                      final result = await FilePicker.platform.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ['pdf'],
                      );
                      if (result != null && result.files.isNotEmpty) {
                        final file = File(result.files.first.path!);
                        _prepareFilePreview(file, 'pdf');
                      }
                    },
                  ),
                ],
              ),
              SizedBox(height: 12.h),
            ],
          ),
        );
      },
    );

  }

  Widget _buildIconAction({
    required String iconPath,
    required String label,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(12.r),
            decoration: BoxDecoration(
              color: onTap == null ? Colors.grey.shade200 : AppColors.main.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: SvgPicture.asset(
              iconPath,
              width: 24.sp,
              height: 24.sp,
              color: onTap == null ? Colors.grey : null,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            label,
            style: AppTextStyles.getText3(context).copyWith(
              fontSize: 10.sp,
              color: onTap == null ? Colors.grey : Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }


  void _prepareFilePreview(File file, String fileType) {
    setState(() {
      _selectedImageFiles.add(file);
      _pendingFileType = fileType;
    });
  }

  void _prepareMultipleFilePreviews(List<File> files, String fileType) {
    final newFiles = files.where((newFile) {
      return !_selectedImageFiles.any((existing) => existing.path == newFile.path);
    }).toList();

    final availableSpace = 8 - _selectedImageFiles.length;
    final limitedNewFiles = newFiles.take(availableSpace).toList();

    setState(() {
      _selectedImageFiles.addAll(limitedNewFiles);
      _pendingFileType = fileType;
    });
  }

  Widget _buildPreviewAttachment() {
    final local = AppLocalizations.of(context)!;

    // ✅ إذا كان هناك مستند مرفق من صفحة الوثائق
    if (widget.attachedDocument != null) {
      final fileName = widget.attachedDocument!.name ?? 'document.pdf';
      final shortName = fileName.length > 30 ? fileName.substring(0, 27) + '...' : fileName;

      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12.r),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                border: Border.all(color: AppColors.main.withOpacity(0.4)),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Row(
                children: [
                  SvgPicture.asset(
                    'assets/icons/pdf-file.svg',
                    width: 24.sp,
                    height: 24.sp,
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      shortName,
                      style: AppTextStyles.getText2(context)
                          .copyWith(fontSize: 12.sp, color: Colors.black87),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 18.sp, color: AppColors.main),
                    onPressed: () {
                      setState(() {
                        _attachedDocument  = null;
                        _selectedImageFiles.clear();
                        _pendingFileType = null;
                        _showAllAttachments = false;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // ✅ لا يوجد مرفقات صور
    if (_selectedImageFiles.isEmpty) return const SizedBox();

    final isPdf = _pendingFileType == 'pdf';

    // ✅ عرض PDF مرفق من المحادثة
    if (isPdf) {
      final fileName = _selectedImageFiles.first.path.split('/').last;
      final shortName = fileName.length > 30 ? fileName.substring(0, 27) + '...' : fileName;

      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12.r),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                border: Border.all(color: AppColors.main.withOpacity(0.4)),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Row(
                children: [
                  SvgPicture.asset(
                    'assets/icons/pdf-file.svg',
                    width: 24.sp,
                    height: 24.sp,
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      shortName,
                      style: AppTextStyles.getText2(context)
                          .copyWith(fontSize: 12.sp, color: Colors.black87),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 18.sp, color: AppColors.main),
                    onPressed: () {
                      setState(() {
                        _selectedImageFiles.clear();
                        _pendingFileType = null;
                        _showAllAttachments = false;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // ✅ عرض صور متعددة
    final count = _selectedImageFiles.length.clamp(0, 8);
    final label = count == 1 ? '${local.attachedImage}' : '$count ${local.attachedImages}';

    final double imageSize = 30.w;
    final double spacing = 6.w;

    List<Widget> firstRow = [];
    List<Widget> secondRow = [];

    int firstRowCount = (count <= 4)
        ? count
        : (count <= 6)
        ? 3
        : 4;

    for (int i = 0; i < min(firstRowCount, count); i++) {
      firstRow.add(
        ClipRRect(
          borderRadius: BorderRadius.circular(6.r),
          child: Image.file(
            _selectedImageFiles[i],
            width: imageSize,
            height: imageSize,
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    if (!_showAllAttachments && count > firstRowCount) {
      firstRow.add(
        ClipRRect(
          borderRadius: BorderRadius.circular(6.r),
          child: Container(
            width: imageSize,
            height: imageSize,
            color: AppColors.main.withOpacity(0.15),
            alignment: Alignment.center,
            child: Text(
              '+${count - firstRowCount}',
              style: AppTextStyles.getText3(context).copyWith(
                fontSize: 10.sp,
                color: AppColors.main,
              ),
            ),
          ),
        ),
      );
    }

    if (_showAllAttachments && count > firstRowCount) {
      for (int i = firstRowCount; i < count; i++) {
        secondRow.add(
          ClipRRect(
            borderRadius: BorderRadius.circular(6.r),
            child: Image.file(
              _selectedImageFiles[i],
              width: imageSize,
              height: imageSize,
              fit: BoxFit.cover,
            ),
          ),
        );
      }
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.r),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              border: Border.all(color: AppColors.main.withOpacity(0.4)),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _showAllAttachments = !_showAllAttachments;
                });
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Wrap(spacing: spacing, children: firstRow),
                      const Spacer(),
                      if (secondRow.isEmpty)
                        Row(
                          children: [
                            Text(
                              label,
                              style: AppTextStyles.getText2(context).copyWith(fontSize: 10.sp, color: Colors.black87),
                            ),
                            SizedBox(width: 4.w),
                            IconButton(
                              icon: Icon(Icons.close, size: 18.sp, color: AppColors.main),
                              onPressed: () {
                                setState(() {
                                  _selectedImageFiles.clear();
                                  _pendingFileType = null;
                                  _showAllAttachments = false;
                                });
                              },
                            ),
                          ],
                        ),
                    ],
                  ),
                  if (secondRow.isNotEmpty)
                    Row(
                      children: [
                        Wrap(spacing: spacing, runSpacing: spacing, children: secondRow),
                        const Spacer(),
                        Row(
                          children: [
                            Text(
                              label,
                              style: AppTextStyles.getText2(context).copyWith(fontSize: 10.sp, color: Colors.black87),
                            ),
                            SizedBox(width: 4.w),
                            IconButton(
                              icon: Icon(Icons.close, size: 18.sp, color: AppColors.main),
                              onPressed: () {
                                setState(() {
                                  _selectedImageFiles.clear();
                                  _pendingFileType = null;
                                  _showAllAttachments = false;
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: SizedBox(
          height: 65.h,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.grayMain.withOpacity(0.15),
              border: Border(top: BorderSide(color: Colors.grey.shade300, width: 0.5)),
            ),
            padding: EdgeInsets.only(right: 8.w, top: 8.h, left: 8.w, bottom: 15.h),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: _showAttachmentOptions,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4.w),
                          child: Icon(Icons.add, size: 22.sp, color: AppColors.main),
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          style: AppTextStyles.getText3(context).copyWith(fontSize: 12.sp), // ✅ حجم النص المكتوب
                          decoration: InputDecoration(
                            hintText: AppLocalizations.of(context)!.writeYourMessage,
                            hintStyle: AppTextStyles.getText3(context).copyWith(fontSize: 11.sp, color: Colors.grey),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.8),
                            contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30.r),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                CircleAvatar(
                  radius: 18.r,
                  backgroundColor: AppColors.main,
                  child: IconButton(
                    icon: Icon(Icons.send, color: Colors.white, size: 18.sp),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClosedInfo(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // ✅ فقط محتوى الـ Container يتأثر بـ blur
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    color: AppColors.grayMain.withOpacity(0.2),
                  ),
                ),
              ),

              // ✅ النص فوق الخلفية المبلورة
              Padding(
                padding: EdgeInsets.all(14.w),
                child: Text(
                  AppLocalizations.of(context)!.conversationClosed,
                  style: AppTextStyles.getText3(context).copyWith(
                    fontSize: 12.sp,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWaitingDoctorReply(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        border: Border.all(color: AppColors.main, width: 2),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Center(
        child: Text(
          AppLocalizations.of(context)!.waitingDoctorReply,
          style: AppTextStyles.getText3(context).copyWith(fontSize: 12.sp, color: AppColors.main),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildAttachmentBubble(List<Map<String, dynamic>> attachments, bool isUser, Widget avatar, DateTime? time,  {required bool showSenderName}) {
    final images = attachments.where((a) => a['type'] == 'image').toList();
    final pdfs = attachments.where((a) => a['type'] == 'pdf').toList();
    final lang = Localizations.localeOf(context).languageCode;
    final validImages = images
        .map((e) => e['file_url'] ?? e['fileUrl'])
        .where((url) => url != null && url is String && url.trim().isNotEmpty)
        .cast<String>()
        .toList();
    final currentUserId = Supabase.instance.client.auth.currentUser?.id ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (images.isEmpty && pdfs.isNotEmpty)
          Stack(
            clipBehavior: Clip.none,
            children: [
              Align(
                alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showSenderName)
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: 4.h,
                          right: isUser ? 14.w : 0,
                          left: isUser ? 0 : 14.w,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            avatar,
                            SizedBox(width: 6.w),
                            Text(
                              isUser ? widget.accountHolderName : widget.doctorName,
                              style: AppTextStyles.getText2(context).copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                                fontSize: 12.sp,
                              ),
                            ),
                          ],
                        ),
                      ),

                    GestureDetector(
                      onTap: () {
                        final pdf = pdfs.first;
                        final userDoc = UserDocument(
                          id: '',
                          userId: currentUserId,
                          name: pdf['file_name'] ?? pdf['fileName'] ?? 'PDF File',
                          type: '',
                          fileType: 'pdf',
                          patientId: widget.patientName,
                          previewUrl: pdf['file_url'] ?? pdf['fileUrl'] ?? '',
                          pages: [pdf['file_url'] ?? pdf['fileUrl'] ?? ''],
                          uploadedAt: DateTime.now(),
                          uploadedById: '',
                          cameFromConversation: true,
                          conversationDoctorName: widget.doctorName,
                        );

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DocumentPreviewPage(document: userDoc, cameFromConversation: true, doctorName: widget.doctorName),
                          ),
                        );
                      },
                      child: Container(
                        constraints: BoxConstraints(minWidth: 0.3.sw, maxWidth: 0.6.sw),
                        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 20.h),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8.r),
                          border: Border.all(color: AppColors.main.withOpacity(0.4)),
                        ),
                        child: Row(
                          children: [
                            SvgPicture.asset('assets/icons/pdf-file.svg', width: 20.w, height: 20.w),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: Text(
                                pdfs.first['file_name'] ?? pdfs.first['fileName'] ?? 'PDF File',
                                style: AppTextStyles.getText2(context),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Padding(
                      padding: EdgeInsets.only(right: isUser ? 14.w : 0, left: isUser ? 0 : 14.w),
                      child: Align(
                        alignment: Alignment.bottomRight,
                        child: Text(
                          time != null ? intl.DateFormat('HH:mm').format(time!) : '',
                          style: AppTextStyles.getText3(context).copyWith(
                            fontSize: 10.sp,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (!showSenderName)
                Positioned(
                  top: 4.h,
                  left: isUser ? null : -16.w,
                  right: isUser ? -16.w : null,
                  child: avatar,
                ),


            ],
          ),

        if (images.isNotEmpty)
          Stack(
            clipBehavior: Clip.none,
            children: [
              Align(
                alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showSenderName)
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: 4.h,
                          right: isUser ? 10.w : 0,
                          left: isUser ? 0 : 10.w,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            avatar,
                            SizedBox(width: 6.w),
                            Text(
                              isUser ? widget.accountHolderName : widget.doctorName,
                              style: AppTextStyles.getText2(context).copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                                fontSize: 12.sp,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12.r),
                      child: GestureDetector(
                        onTap: () => _showImageOverlay(validImages),
                        child: Container(
                          constraints: BoxConstraints(maxWidth: 0.5.sw),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: GridView.count(
                            crossAxisCount: images.length == 1 ? 1 : 2,
                            childAspectRatio: 1,
                            shrinkWrap: true,
                            crossAxisSpacing: 6.w,
                            mainAxisSpacing: 6.h,
                            physics: const NeverScrollableScrollPhysics(),
                              children: List.generate(min(4, images.length), (i) {
                                final imageUrl = validImages[i];

                                if (i == 3 && validImages.length > 4) {
                                  return GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _expandedImageUrls = validImages;
                                        _expandedImageOverlay = true;
                                        _showAsGrid = true; // ✅ لعرض الصور كشبكة
                                      });
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: AppColors.main.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8.r),
                                      ),
                                      child: Center(
                                        child: CircleAvatar(
                                          radius: 16.r,
                                          backgroundColor: Colors.white.withOpacity(0.85),
                                          child: Text(
                                              '+${validImages.length - 3}',
                                              style: AppTextStyles.getText3(context).copyWith(
                                              fontSize: 10.sp,
                                              color: AppColors.main,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                } else {
                                  // ✅ فتح صورة واحدة في صفحة المعاينة المخصصة
                                  return GestureDetector(
                                    onTap: () {
                                      _showAsGrid = false;
                                      _showImageOverlayWithIndex(
                                        validImages,
                                        i,
                                      );
                                    },
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8.r),
                                      child: _imageCache.containsKey(imageUrl)
                                          ? Image(image: _imageCache[imageUrl]!, fit: BoxFit.cover)
                                          : FadeInImage(
                                        placeholder: MemoryImage(kTransparentImage),
                                        image: CachedNetworkImageProvider(imageUrl),
                                        fadeInDuration: const Duration(milliseconds: 100),
                                        fit: BoxFit.cover,
                                        placeholderFit: BoxFit.cover,
                                        imageErrorBuilder: (_, __, ___) => const Icon(Icons.error),
                                      ),
                                    ),

                                  );
                                }
                              }),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Padding(
                      padding: EdgeInsets.only(right: isUser ? 14.w : 0, left: isUser ? 0 : 14.w),
                      child: Align(
                        alignment: Alignment.bottomRight,
                        child: Text(
                          time != null ? intl.DateFormat('HH:mm').format(time.toLocal()) : '',
                          style: AppTextStyles.getText3(context).copyWith(
                            fontSize: 10.sp,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (!showSenderName)
                Positioned(
                  top: 4.h,
                  left: isUser ? null : -16.w,
                  right: isUser ? -16.w : null,
                  child: avatar,
                ),

            ],
          ),

      ],
    );
  }

  Widget _buildTextBubble(String content, List<Map<String, dynamic>> attachments, bool isUser, Widget avatar, bool showReason, DateTime? time, bool isArabic,  {required bool showSenderName}) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 1, sigmaY: 1),
        child: IntrinsicWidth(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: 0.15.sw,
              maxWidth: 0.6.sw, // أو 0.6.sw حسب رغبتك
            ),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: isUser
                    ? AppColors.mainDark.withOpacity(0.9)
                    : AppColors.grayMain.withOpacity(0.25),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12.r),
                  topRight: Radius.circular(12.r),
                  bottomLeft: isUser ? Radius.circular(12.r) : Radius.zero,
                  bottomRight: isUser ? Radius.zero : Radius.circular(12.r),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showSenderName)
                    Row(children: [avatar, SizedBox(width: 8.w), Text(isUser ? widget.accountHolderName : widget.doctorName, style: AppTextStyles.getText2(context).copyWith(color: isUser ? Colors.white : Colors.black, fontWeight: FontWeight.bold))]),

                  if (showSenderName) SizedBox(height: 10.h), // 👈 move the spacing inside the condition
                  Directionality(
                    textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
                    child: Text(
                      content,
                      style: AppTextStyles.getText2(context).copyWith(
                        color: isUser ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  SizedBox(height: 4.h),
                  if (attachments.isEmpty)
                    Align(
                    alignment: Alignment.bottomRight,
                    child: Text(
                      time != null ? intl.DateFormat('HH:mm').format(time.toLocal()) : '',
                      style: AppTextStyles.getText3(context).copyWith(
                        fontSize: 10.sp,
                        color: isUser ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }


  void _navigateToDocumentInfoPage(List<String> imagePaths) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentInfoScreen(
          images: imagePaths,
          cameFromMultiPage: imagePaths.length > 1,
          initialName: imagePaths.length == 1 ? 'Document' : null,
        ),
      ),
    );
  }

  Future<String> _downloadAndGetLocalPath(String url) async {
    final response = await http.get(Uri.parse(url));
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/${path.basename(url)}');
    await file.writeAsBytes(response.bodyBytes);
    return file.path;
  }




  @override
  Widget build(BuildContext context) {
    super.build(context); // ضروري لـ AutomaticKeepAliveClientMixin
    final isForRelative = widget.patientName != widget.accountHolderName;
    final lang = Localizations.localeOf(context).languageCode;
    final local = AppLocalizations.of(context)!;
    bool _isProcessingAddToDocument = false;
    bool _isProcessingSave = false;

    return WillPopScope(
      onWillPop: () async {
        if (_expandedImageOverlay) {
          _hideImageOverlay();
          return false;
        }
        Navigator.pushAndRemoveUntil(
          context,
          fadePageRoute(const CustomBottomNavigationBar(initialIndex: 3)),
              (route) => false,
        );
        return false;
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.main,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.chevron_left, color: Colors.white, size: 28.sp),
            onPressed: () {
              if (_expandedImageOverlay) {
                _hideImageOverlay();
              } else {
                Navigator.pushAndRemoveUntil(
                  context,
                  fadePageRoute(const CustomBottomNavigationBar(initialIndex: 3)), // assuming index 3 = Messages tab
                      (route) => false,
                );
              }
            },
          ),
          titleSpacing: 0,
          title: Row(
            children: [
              CircleAvatar(
                radius: 18.r,
                backgroundColor: AppColors.whiteText.withOpacity(0.35),
                backgroundImage: widget.doctorImage,
              ),
              SizedBox(width: 10.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.doctorName,
                      style: AppTextStyles.getTitle2(context).copyWith(color: Colors.white, fontSize: 14.sp)),
                  Text(widget.doctorSpecialty,
                      style: AppTextStyles.getText2(context).copyWith(color: Colors.white70, fontSize: 11.sp)),
                ],
              )
            ],
          ),
        ),
        body: Stack(
            children: [
        Positioned.fill(
        child: Image.asset('assets/images/Chat-BG.png', fit: BoxFit.cover),
      ),
      Column(
      children: [
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _messageStream,
                builder: (context, snapshot) {
                  print('📡 Stream connectionState: ${snapshot.connectionState}');
                  print('📡 snapshot.hasData: ${snapshot.hasData}');
                  print('📡 snapshot.data: ${snapshot.data}');
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    print('⏳ Loading messages...');
                    return const Center(
                      child: CircularProgressIndicator(color: AppColors.main),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data == null) {
                    print('⚠️ No data received from stream.');
                    return const Center(
                      child: Text('لا توجد رسائل بعد.'),
                    );
                  }
                  final messages = snapshot.data!;
                  print('✅ Messages received: ${messages.length}');
      
                  // Future.delayed(const Duration(milliseconds: 100), () {
                  //   if (_scrollController.hasClients &&
                  //       _scrollController.position.maxScrollExtent > 0) {
                  //     _scrollController.jumpTo(
                  //       _scrollController.position.maxScrollExtent,
                  //     );
                  //   }
                  // });
      
      
      
                  if (_shouldAutoScroll &&
                      !_expandedImageOverlay &&
                      _scrollController.hasClients &&
                      _isUserAtBottom) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
                      print('📍 Auto-scroll to bottom (jumpTo)');
                    });
                  }
      
                  if (_shouldAutoScroll &&
                      !_expandedImageOverlay &&
                      _selectedImageFiles.isNotEmpty &&
                      _scrollController.hasClients &&
                      _isUserAtBottom) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _scrollController.animateTo(
                        _scrollController.position.maxScrollExtent + 50,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                      print('📍 Auto-scroll with animation (animateTo)');
                    });
                  }
      
      
                  // التمرير التلقائي عند فتح الصفحة أو تحميل الرسائل
                  if (_shouldAutoScroll && !_expandedImageOverlay) {
                    Future.delayed(const Duration(milliseconds: 100), () {
                      if (_shouldAutoScroll &&
                          !_expandedImageOverlay &&
                          _scrollController.hasClients &&
                          _isUserAtBottom &&
                          _scrollController.position.maxScrollExtent > 0) {
                        _scrollController.jumpTo(
                          _scrollController.position.maxScrollExtent,
                        );
                      }
                    });
                  }
      
                  if (_shouldAutoScroll && !_expandedImageOverlay && _selectedImageFiles.isNotEmpty) {
                    Future.delayed(const Duration(milliseconds: 100), () {
                      if (_shouldAutoScroll &&
                          !_expandedImageOverlay &&
                          _scrollController.hasClients &&
                          _isUserAtBottom &&
                          _scrollController.position.maxScrollExtent > 0) {
                        _scrollController.animateTo(
                          _scrollController.position.maxScrollExtent + 50,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        );
                      }
                    });
                  }
      
      
                  // ✅ تحديث حالة القراءة إذا كانت الرسالة من الطبيب
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _markMessagesAsRead(messages);
                  });
      
      
      
      
      
                  // ✅ ثاني شيء: تحديد إذا الطبيب رد
                  final doctorHasReplied = messages.any((msg) => msg['is_user'] == false);
      
                  bool firstUserMessageFound = false;
      
      
                  return Stack(
                    children: [
                      Positioned.fill(
                          child: ListView.builder(
                            controller: _scrollController,
                            padding: EdgeInsets.only(
                              left: 20.w,
                              top: widget.isClosed
                                  ? 25.h
                                  : isForRelative
                                  ? 20.h
                                  : 12.h,
                              right: 20.w,
                              bottom: _selectedImageFiles.isNotEmpty || _pendingMessages.isNotEmpty ? 125.h : 65.h,
                            ),
                            itemCount: messages.length + _pendingMessages.length,
                            itemBuilder: (context, index) {
                              if (index >= messages.length) {
                                final pending = _pendingMessages[index - messages.length];
                                final isSingle = pending.files.length == 1;
      
                                return Padding(
                                  padding: EdgeInsets.only(bottom: 12.h),
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        Container(
                                          constraints: BoxConstraints(maxWidth: 0.6.sw),
                                          decoration: BoxDecoration(
                                            color: Colors.transparent,
                                            borderRadius: BorderRadius.circular(12.r),
                                          ),
                                          child: pending.type == 'image'
                                              ? isSingle
                                              ? ShimmerWidget(width: 0.5.sw, height: 0.5.sw, radius: 12.r)
                                              : GridView.builder(
                                            shrinkWrap: true,
                                            physics: NeverScrollableScrollPhysics(),
                                            itemCount: pending.files.length.clamp(1, 4),
                                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                              crossAxisCount: 2,
                                              crossAxisSpacing: 6.w,
                                              mainAxisSpacing: 6.h,
                                            ),
                                            itemBuilder: (_, i) => ShimmerWidget(
                                              width: 120.w,
                                              height: 120.w,
                                              radius: 10.r,
                                            ),
                                          )
                                              : ShimmerWidget(width: 0.7.sw, height: 60.h, radius: 10.r),
                                        ),
                                        Positioned(
                                          top: 4.h,
                                          right: -16.w,
                                          child: CircleAvatar(
                                            radius: 6.r,
                                            backgroundColor: AppColors.main.withOpacity(0.9),
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: Transform.translate(
                                                offset: const Offset(0, -1.5),
                                                child: Text(
                                                  _getInitials(widget.accountHolderName),
                                                  style: AppTextStyles.getText3(context).copyWith(
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.whiteText,
                                                    fontSize: 7.sp,
                                                    height: 1.0,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
      
                              }
      
      // ✅ الرسائل الحقيقية (نفس الكود السابق لديك كما هو)
                              final msg = messages[index];
                              final isUser = msg['is_user'] ?? false;
                              final content = msg['text'] ?? '';
                              final attachments = (msg['attachments'] as List?)?.cast<Map<String, dynamic>>() ?? [];
                              final timestamp = DateTime.tryParse(msg['timestamp'] ?? '');
                              final time = timestamp;
                              final readByDoctorAt = DateTime.tryParse(msg['readByDoctorAt'] ?? '');
                              final bool isReadByDoctor = isUser && (msg['read_by_doctor'] == true);
                              final bool isLastRead = isReadByDoctor && (index == messages.length - 1);
                              bool showSenderName = true;
      
                              if (index > 0) {
                                final prev = messages[index - 1];
                                final prevSender = prev['is_user'] ?? false;
                                if (prevSender == isUser) {
                                  showSenderName = false;
                                }
                              }
      
      
                              final avatar = isUser
                                  ? CircleAvatar(
                                radius: 12.r,
                                backgroundColor: AppColors.whiteText.withOpacity(0.6),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Transform.translate(
                                    offset: const Offset(0, -1.5),
                                    child: Text(
                                      _getInitials(widget.accountHolderName),
                                      style: AppTextStyles.getText3(context).copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.main,
                                        height: 1.0,
                                      ),
                                      textAlign: TextAlign.center,
                                      textHeightBehavior: const TextHeightBehavior(
                                        applyHeightToFirstAscent: false,
                                        applyHeightToLastDescent: false,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                                  : CircleAvatar(
                                radius: 12.r,
                                backgroundColor: AppColors.main.withOpacity(0.55),
                                backgroundImage: widget.doctorImage,
                              );
      
                              final avatar2 = isUser
                                  ? CircleAvatar(
                                radius: 6.r,
                                backgroundColor: AppColors.main.withOpacity(0.8),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Transform.translate(
                                    offset: const Offset(0, -1.5),
                                    child: Text(
                                      _getInitials(widget.accountHolderName),
                                      style: AppTextStyles.getText3(context).copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.whiteText,
                                        height: 1.0,
                                      ),
                                      textAlign: TextAlign.center,
                                      textHeightBehavior: const TextHeightBehavior(
                                        applyHeightToFirstAscent: false,
                                        applyHeightToLastDescent: false,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                                  : CircleAvatar(
                                radius: 12.r,
                                backgroundColor: AppColors.main.withOpacity(0.55),
                                backgroundImage: widget.doctorImage,
                              );
      
                              final showReason = isUser && !firstUserMessageFound;
                              if (showReason) firstUserMessageFound = true;
                              final isArabic = _isArabicText(content);
      
                              DateTime? currentDate = time != null ? DateTime(time.year, time.month, time.day) : null;
                              DateTime? previousDate;
                              if (index > 0) {
                                final previousTimestampString = (messages[index - 1])['timestamp'] as String?;
                                final previousTime = previousTimestampString != null ? DateTime.tryParse(previousTimestampString) : null;
                                if (previousTime != null) {
                                  previousDate = DateTime(previousTime.year, previousTime.month, previousTime.day);
                                }
                              }
                              final showDateDivider = currentDate != null && currentDate != previousDate;
      
                              return Padding(
                                padding: EdgeInsets.only(bottom: 12.h),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    if (showDateDivider && time != null) ...[
                                      Padding(
                                        padding: EdgeInsets.symmetric(vertical: 10.h),
                                        child: Row(
                                          children: [
                                            Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
                                            Padding(
                                              padding: EdgeInsets.symmetric(horizontal: 8.w),
                                              child: Text(
                                                _getDayLabel(time, lang),
                                                style: AppTextStyles.getText3(context).copyWith(
                                                  fontSize: 11.sp,
                                                  color: Colors.black54,
                                                ),
                                              ),
                                            ),
                                            Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
                                          ],
                                        ),
                                      ),
                                    ],
                                    Align(
                                      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                                      child: Column(
                                        crossAxisAlignment: isUser ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                                        children: [
                                          Align(
                                            alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                                            child: Column(
                                              crossAxisAlignment: isUser ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                                              children: [
                                                if (content.trim().isNotEmpty)
                                                  _buildTextBubble(content, attachments, isUser, avatar, showReason, time, isArabic, showSenderName: showSenderName),
      
                                                if (attachments.isNotEmpty)
                                                  Padding(
                                                    padding: EdgeInsets.only(top: 6.h),
                                                    child: _buildAttachmentBubble(attachments, isUser, avatar2, time, showSenderName: showSenderName),
                                                  ),
      
                                                if (isLastRead) ...[
                                                  SizedBox(height: 4.h),
                                                  Align(
                                                    alignment: lang == 'ar' ? Alignment.centerRight : Alignment.centerLeft,
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        CircleAvatar(
                                                          radius: 7.r,
                                                          backgroundImage: widget.doctorImage,
                                                          backgroundColor: AppColors.main.withOpacity(0.5),
                                                        ),
                                                        SizedBox(width: 4.w),
                                                        Text(
                                                          '${local.read} • ${_formatReadTime(readByDoctorAt, lang)}',
                                                          style: AppTextStyles.getText3(context).copyWith(fontSize: 9.sp, color: Colors.grey),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          )
                      ),
                      if (!widget.isClosed && doctorHasReplied && _selectedImageFiles.isNotEmpty && _pendingMessages.isEmpty)
                        Positioned(
                          bottom: 70.h,
                          left: 0,
                          right: 0,
                          child: _buildPreviewAttachment(),
                        ),
      
      
                      if (!widget.isClosed && doctorHasReplied)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: _buildTextField(context),
                        )
      
                      else if (widget.isClosed)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: _buildClosedInfo(context),
                        )
                      else
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: _buildWaitingDoctorReply(context),
                        ),
      
                      Positioned(
                        bottom: (_selectedImageFiles.isNotEmpty || _pendingMessages.isNotEmpty) ? 150.h : 75.h,
                        left: 0,
                        right: 0,
                        child: AnimatedOpacity(
                          duration: Duration(milliseconds: 200),
                          opacity: _showScrollToBottom ? 1 : 0,
                          child: Visibility(
                            visible: _showScrollToBottom,
                            child: Center(
                              child: GestureDetector(
                                onTap: () {
                                  _scrollController.animateTo(
                                    _scrollController.position.maxScrollExtent,
                                    duration: Duration(milliseconds: 300),
                                    curve: Curves.easeOut,
                                  );
                                },
                                child: Container(
                                  width: 26.w,
                                  height: 26.w,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.main.withOpacity(0.3),
                                    border: Border.all(color: AppColors.main, width: 1.w),
                                  ),
                                  child: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.main, size: 20.sp),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
      
                    ],
                  );
                },
      
              ),
            ),
          ],
        ),
              if (widget.isClosed)
                ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      width: double.infinity,
                      color: AppColors.main.withOpacity(0.5),
                      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                      child: Row(
                        children: [
                          const Icon(Icons.lock_outline, size: 18, color: Colors.black54),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Text(
                              local.conversationClosedByDoctor(widget.doctorName),
                              style: AppTextStyles.getText2(context).copyWith(fontSize: 11.sp),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
      
              if (isForRelative && !widget.isClosed)
                ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      width: double.infinity,
                      color: Colors.white10.withOpacity(0.65),
                      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                      child: Row(
                        children: _isArabicText(widget.patientName)
                            ? [
                          Text(
                            '${local.messageForPatient}   ',
                            style: AppTextStyles.getText2(context).copyWith(fontSize: 10.sp, color: Colors.black87),
                          ),
                          CircleAvatar(
                            radius: 10.r,
                            backgroundColor: AppColors.main.withOpacity(0.9),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Transform.translate(
                                offset: const Offset(0, -1.5),
                                child: Text(
                                  _getInitials(widget.patientName),
                                  style: AppTextStyles.getText3(context).copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.whiteText,
                                    fontSize: 9.sp,
                                    height: 1.0,
                                  ),
                                  textAlign: TextAlign.center,
                                  textHeightBehavior: const TextHeightBehavior(
                                    applyHeightToFirstAscent: false,
                                    applyHeightToLastDescent: false,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 6.w),
                          Text(
                            widget.patientName,
                            style: AppTextStyles.getText2(context).copyWith(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(width: 6.w),
                        ]
                            : [
                          CircleAvatar(
                            radius: 10.r,
                            backgroundColor: AppColors.main.withOpacity(0.9),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Transform.translate(
                                offset: const Offset(0, -1.5),
                                child: Text(
                                  _getInitials(widget.patientName),
                                  style: AppTextStyles.getText3(context).copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.whiteText,
                                    fontSize: 9.sp,
                                    height: 1.0,
                                  ),
                                  textAlign: TextAlign.center,
                                  textHeightBehavior: const TextHeightBehavior(
                                    applyHeightToFirstAscent: false,
                                    applyHeightToLastDescent: false,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 6.w),
                          Text(
                            widget.patientName,
                            style: AppTextStyles.getText2(context).copyWith(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(width: 6.w),
                          Text(
                            local.messageForPatient,
                            style: AppTextStyles.getText2(context).copyWith(fontSize: 12.sp, color: Colors.black87),
                          ),
                        ],
                      ),
                    ),),),
              if (_expandedImageOverlay)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () {
                      if (_showImageDownloadOptions) {
                        setState(() => _showImageDownloadOptions = false);
                      }
                    },
                    child: Container(
                      color: Colors.black.withOpacity(0.85),
                      child: SafeArea(
                        child: Column(
                          children: [
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // زر الإغلاق (يسار في العربية)
                                  Align(
                                    alignment: lang == 'ar' ? Alignment.centerRight : Alignment.centerLeft,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(24.r),
                                      child: BackdropFilter(
                                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                        child: Container(
                                          padding: EdgeInsets.symmetric(horizontal: 4.w),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(24.r),
                                          ),
                                          child: IconButton(
                                            icon: Icon(Icons.close, color: Colors.white, size: 18.sp),
                                            onPressed: _hideImageOverlay,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
      
                                  // النص في الوسط
                                  if (!_showAsGrid && !_showImageDownloadOptions)
                                    Align(
                                      alignment: Alignment.center,
                                      child: Text(
                                        '${_initialImageIndex + 1} ${AppLocalizations.of(context)!.ofText} ${_expandedImageUrls.length}',
                                        style: AppTextStyles.getText1(context).copyWith(color: Colors.white),
                                      ),
                                    ),
      
                                  // الأزرار الجانبية (يمين في العربية)
                                  Align(
                                    alignment: lang == 'ar' ? Alignment.centerLeft : Alignment.centerRight,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (!_showAsGrid)
                                          Align(
                                            alignment: Alignment.bottomRight,
                                            child: AnimatedSwitcher(
                                              duration: const Duration(milliseconds: 250),
                                              child: _showImageDownloadOptions
                                                  ? Container(
                                                key: const ValueKey('expanded'),
                                                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                                                decoration: BoxDecoration(
                                                  color: Colors.white.withOpacity(0.15),
                                                  borderRadius: BorderRadius.circular(24.r),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Tooltip(
                                                      message: AppLocalizations.of(context)!.addToDocuments,
                                                      waitDuration: const Duration(milliseconds: 500),
                                                      child: StatefulBuilder(
                                                        builder: (context, setLocalState) {
                                                          return GestureDetector(
                                                            onTap: _isProcessingAddToDocument
                                                                ? null
                                                                : () {
                                                              print('>>> Add single to document pressed');
                                                              setLocalState(() => _isProcessingAddToDocument = true);
      
                                                              Future.delayed(Duration(milliseconds: 50), () async {
                                                                final imageUrl = _expandedImageUrls[_initialImageIndex];
                                                                final localPath = await _downloadAndGetLocalPath(imageUrl);
      
                                                                if (!context.mounted) return;
      
                                                                setLocalState(() => _isProcessingAddToDocument = false);
                                                                print('>>> Navigating with: $localPath');
      
                                                                _navigateToDocumentInfoPage([localPath]);
                                                              });
                                                            },
                                                            child: _isProcessingAddToDocument
                                                                ? SizedBox(
                                                              width: 18.sp,
                                                              height: 18.sp,
                                                              child: CircularProgressIndicator(
                                                                color: Colors.white,
                                                                strokeWidth: 2,
                                                              ),
                                                            )
                                                                : SvgPicture.asset(
                                                              'assets/icons/add2document_white.svg',
                                                              width: 22.sp,
                                                              height: 22.sp,
                                                              color: Colors.white,
                                                            ),
                                                          );
                                                        },
                                                      ),
                                                    ),
      
                                                    SizedBox(width: 20.w),
                                                    /// زر "الحفظ" لصورة واحدة
                                                    Tooltip(
                                                      message: AppLocalizations.of(context)!.save,
                                                      waitDuration: const Duration(milliseconds: 500),
                                                      child: StatefulBuilder(
                                                        builder: (context, setLocalState) {
                                                          return GestureDetector(
                                                            onTap: _isProcessingSave
                                                                ? null
                                                                : () {
                                                              print('>>> Save single image pressed');
                                                              setLocalState(() => _isProcessingSave = true);
      
                                                              Future.delayed(Duration(milliseconds: 50), () async {
                                                                try {
                                                                  final url = _expandedImageUrls[_initialImageIndex];
                                                                  await GallerySaver.saveImage(url);
      
                                                                  if (!context.mounted) return;
      
                                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                                    SnackBar(
                                                                      content: Text(AppLocalizations.of(context)!.downloadCompleted),
                                                                      backgroundColor: AppColors.main.withOpacity(0.9),
                                                                    ),
                                                                  );
                                                                } catch (_) {
                                                                  if (context.mounted) {
                                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                                      SnackBar(
                                                                        content: Text(AppLocalizations.of(context)!.downloadFailed),
                                                                        backgroundColor: AppColors.red.withOpacity(0.9),
                                                                      ),
                                                                    );
                                                                  }
                                                                } finally {
                                                                  if (context.mounted) {
                                                                    setLocalState(() => _isProcessingSave = false);
                                                                  }
                                                                }
                                                              });
                                                            },
                                                            child: _isProcessingSave
                                                                ? SizedBox(
                                                              width: 18.sp,
                                                              height: 18.sp,
                                                              child: CircularProgressIndicator(
                                                                color: Colors.white,
                                                                strokeWidth: 2,
                                                              ),
                                                            )
                                                                : Icon(Icons.save_alt, color: Colors.white, size: 22.sp),
                                                          );
                                                        },
                                                      ),
                                                    ),
      
                                                  ],
                                                ),
                                              )
                                                  : GestureDetector(
                                                key: const ValueKey('collapsed'),
                                                onTap: () {
                                                  setState(() => _showImageDownloadOptions = true);
                                                },
                                                child: Container(
                                                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white.withOpacity(0.15),
                                                    borderRadius: BorderRadius.circular(24.r),
                                                  ),
                                                  child: Column(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.download, color: Colors.white, size: 14.sp),
                                                      SizedBox(width: 6.w),
                                                      Text(
                                                        AppLocalizations.of(context)!.download,
                                                        style: TextStyle(color: Colors.white, fontSize: 9.sp),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
      
      
      
                                        if (!_showAsGrid) ...[
                                          SizedBox(width: 6.w),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(24.r),
                                            child: BackdropFilter(
                                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                              child: Container(
                                                padding: EdgeInsets.symmetric(horizontal: 4.w),
                                                decoration: BoxDecoration(
                                                  color: Colors.white.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(24.r),
                                                ),
                                                child: IconButton(
                                                  icon: Icon(Icons.grid_view, color: Colors.white, size: 16.sp),
                                                  onPressed: () {
                                                    setState(() {
                                                      if (_showImageDownloadOptions) {
                                                        setState(() => _showImageDownloadOptions = false);
                                                      }
                                                      _showAsGrid = true;
                                                    });
                                                  },
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                        if (_showAsGrid) ...[
                                          SizedBox(width: 6.w),
                                          _showImageDownloadOptions
                                              ? Container(
                                            key: const ValueKey('expanded'),
                                            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(24.r),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Tooltip(
                                                  message: AppLocalizations.of(context)!.addToDocuments,
                                                  waitDuration: const Duration(milliseconds: 500),
                                                  child: StatefulBuilder(
                                                    builder: (context, setLocalState) {
                                                      return GestureDetector(
                                                        onTap: _isProcessingAddToDocument
                                                            ? null
                                                            : () {
                                                          print('>>> AddToDocument pressed');
                                                          setLocalState(() => _isProcessingAddToDocument = true); // ✅ تحديث سريع
      
                                                          Future.delayed(Duration(milliseconds: 50), () async {
                                                            print('>>> Now performing download logic...');
                                                            List<String> localPaths = [];
                                                            for (final url in _expandedImageUrls) {
                                                              final path = await _downloadAndGetLocalPath(url);
                                                              localPaths.add(path);
                                                            }
      
                                                            if (!mounted) return;
      
                                                            setLocalState(() => _isProcessingAddToDocument = false); // ✅ إيقاف اللودر
                                                            print('>>> AddToDocument done, navigating...');
                                                            _navigateToDocumentInfoPage(localPaths);
                                                          });
                                                        },
                                                        child: _isProcessingAddToDocument
                                                            ? SizedBox(
                                                          width: 18.sp,
                                                          height: 18.sp,
                                                          child: CircularProgressIndicator(
                                                            color: Colors.white,
                                                            strokeWidth: 2,
                                                          ),
                                                        )
                                                            : SvgPicture.asset(
                                                          'assets/icons/add2document_white.svg',
                                                          width: 22.sp,
                                                          height: 22.sp,
                                                          color: Colors.white,
                                                        ),
                                                      );
                                                    },
                                                  )
      
                                                ),
      
                                                SizedBox(width: 20.w),
      
                                                Tooltip(
                                                  message: AppLocalizations.of(context)!.save,
                                                  waitDuration: const Duration(milliseconds: 500),
                                                  child: StatefulBuilder(
                                                    builder: (context, setLocalState) {
                                                      return GestureDetector(
                                                        onTap: _isProcessingSave
                                                            ? null
                                                            : () async {
                                                          print('>>> Save pressed');
                                                          setLocalState(() => _isProcessingSave = true);
      
                                                          try {
                                                            for (final url in _expandedImageUrls) {
                                                              await GallerySaver.saveImage(url);
                                                            }
      
                                                            if (mounted) {
                                                              ScaffoldMessenger.of(context).showSnackBar(
                                                                SnackBar(
                                                                  content: Text(
                                                                    '${_expandedImageUrls.length} ${AppLocalizations.of(context)!.imagesDownloadedSuccessfully}',
                                                                  ),
                                                                  backgroundColor: AppColors.main.withOpacity(0.9),
                                                                ),
                                                              );
                                                            }
                                                          } catch (_) {
                                                            if (mounted) {
                                                              ScaffoldMessenger.of(context).showSnackBar(
                                                                SnackBar(
                                                                  content: Text(AppLocalizations.of(context)!.imagesDownloadFailed),
                                                                  backgroundColor: AppColors.red.withOpacity(0.9),
                                                                ),
                                                              );
                                                            }
                                                          } finally {
                                                            if (mounted) {
                                                              setLocalState(() => _isProcessingSave = false);
                                                              setState(() => _showImageDownloadOptions = false);
                                                            }
                                                          }
                                                        },
                                                        child: _isProcessingSave
                                                            ? SizedBox(
                                                          width: 18.sp,
                                                          height: 18.sp,
                                                          child: CircularProgressIndicator(
                                                            color: Colors.white,
                                                            strokeWidth: 2,
                                                          ),
                                                        )
                                                            : Icon(Icons.save_alt, color: Colors.white, size: 22.sp),
                                                      );
                                                    },
                                                  ),
                                                )
                                              ],
                                            ),
                                          )
                                              : GestureDetector(
                                            key: const ValueKey('collapsed'),
                                            onTap: () {
                                              setState(() => _showImageDownloadOptions = true);
                                            },
                                            child: Container(
                                              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 15.h),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(24.r),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  _isDownloadingAll
                                                      ? SizedBox(
                                                    width: 16.sp,
                                                    height: 16.sp,
                                                    child: CircularProgressIndicator(
                                                      color: Colors.white,
                                                      strokeWidth: 2,
                                                    ),
                                                  )
                                                      : Icon(Icons.download, color: Colors.white, size: 16.sp),
                                                  SizedBox(width: 4.w),
                                                  Text(
                                                    AppLocalizations.of(context)!.downloadAll,
                                                    style: AppTextStyles.getText3(context).copyWith(
                                                      color: Colors.white,
                                                      fontSize: 10.sp,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          )
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: _showAsGrid
                                  ? GridView.builder(
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 8.w,
                                  mainAxisSpacing: 8.h,
                                ),
                                padding: EdgeInsets.all(16.w),
                                itemCount: _expandedImageUrls.length,
                                itemBuilder: (context, index) {
                                  final url = _expandedImageUrls[index];
                                  return GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        if (_showImageDownloadOptions) {
                                          setState(() => _showImageDownloadOptions = false);
                                        }
                                        _initialImageIndex = index;
                                        _showAsGrid = false;
                                      });
                                    },
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12.r),
                                      child: _imageCache.containsKey(url)
                                          ? Image(image: _imageCache[url]!, fit: BoxFit.cover)
                                          : FadeInImage(
                                        placeholder: MemoryImage(kTransparentImage),
                                        image: CachedNetworkImageProvider(url),
                                        fadeInDuration: const Duration(milliseconds: 100),
                                        fit: BoxFit.cover,
                                        placeholderFit: BoxFit.cover,
                                        imageErrorBuilder: (_, __, ___) => const Icon(Icons.error),
                                      )
      
                                    ),
                                  );
                                },
                              )
                                  : PageView.builder(
                                controller: PageController(initialPage: _initialImageIndex),
                                physics: _isZoomed ? const NeverScrollableScrollPhysics() : null,
                                onPageChanged: (index) {
                                  setState(() {
                                    if (_showImageDownloadOptions) {
                                      setState(() => _showImageDownloadOptions = false);
                                    }
                                    _initialImageIndex = index;
                                    _transformationController.value = Matrix4.identity(); // تصفير عند التبديل
                                    _isZoomed = false;
                                  });
                                },
                                itemCount: _expandedImageUrls.length,
                                itemBuilder: (_, index) {
                                  final url = _expandedImageUrls[index];
                                  return LayoutBuilder(
                                      builder: (context, constraints) {
                                      return GestureDetector(
                                        onDoubleTapDown: (details) {
                                          _doubleTapPosition = details.localPosition;
                                        },
                                        onDoubleTap: () {
                                          final zoomed =  _transformationController.value != Matrix4.identity();
      
                                          if (zoomed) {
                                            _transformationController.value = Matrix4.identity();
                                          } else {
                                            final tap = _doubleTapPosition;
                                            final scale = 2.5;
      
                                            final x = -tap.dx * (scale - 1);
                                            final y = -tap.dy * (scale - 1);
      
                                            _transformationController.value = Matrix4.identity()
                                              ..translate(x, y)
                                              ..scale(scale);
                                          }
                                        },
                                        child: InteractiveViewer(
                                          transformationController: _transformationController,
                                          minScale: 1,
                                          maxScale: 4,
                                          onInteractionUpdate: (details) {
                                            final scale = _transformationController.value.getMaxScaleOnAxis();
                                            if (mounted) {
                                              setState(() {
                                                _isZoomed = scale > 1.0;
                                              });
                                            }
                                          },
                                          onInteractionEnd: (details) {
                                            final scale = _transformationController.value.getMaxScaleOnAxis();
                                            if (mounted) {
                                              setState(() {
                                                _isZoomed = scale > 1.0;
                                              });
                                            }
                                          },
      
                                          child: Center(
                                            child: _imageCache.containsKey(url)
                                                ? Image(image: _imageCache[url]!, fit: BoxFit.cover)
                                                : FadeInImage(
                                              placeholder: MemoryImage(kTransparentImage),
                                              image: CachedNetworkImageProvider(url),
                                              fadeInDuration: const Duration(milliseconds: 100),
                                              fit: BoxFit.cover,
                                              placeholderFit: BoxFit.cover,
                                              imageErrorBuilder: (_, __, ___) => const Icon(Icons.error),
                                            )
      
                                          ),
                                        ),
                                      );
                                    }
                                  );
                                },
                              ),
      
      
                            ),
      
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
      
      
      
            ],
      ),
      ),
    );
  }
}
