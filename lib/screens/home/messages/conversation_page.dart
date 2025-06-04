import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:docsera/models/document.dart';
import 'package:docsera/screens/home/Document/document_preview_page.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart' as intl;
import 'package:path_provider/path_provider.dart';
import 'package:transparent_image/transparent_image.dart';
import 'package:url_launcher/url_launcher.dart';


class ConversationPage extends StatefulWidget {
  final String conversationId;
  final String doctorName;
  final String doctorSpecialty;
  final String doctorImage;
  final bool isClosed;
  final String patientName;
  final String accountHolderName;
  final String selectedReason;
  final UserDocument? attachedDocument;

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
  }) : super(key: key);

  @override
  State<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends State<ConversationPage> {
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

  @override
  void initState() {
    super.initState();

    if (widget.attachedDocument != null) {
      final doc = widget.attachedDocument!;
      final type = doc.type;
      final fileType = doc.fileType;
      final preview = doc.previewUrl;
      final isRealPdf = doc.fileType == 'pdf';

      print('🧪 Document Received in ConversationPage');
      print('📂 doc.type: $type');
      print('📂🔍 doc.fileType: $fileType');
      print('🌐 doc.previewUrl: $preview');
      print('🔍 parsed path: ${Uri.parse(preview).path}');


      if (isRealPdf) {
        print('✅ Will treat as PDF');
        _pendingFileType = 'pdf';
        _selectedImageFiles.clear();
        _selectedImageFiles.add(File('/tmp/${doc.name}.pdf'));
      } else {
        print('🖼️ Will treat as IMAGE');
        _pendingFileType = 'image';
        _selectedImageFiles.clear();
      }
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
    });
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


  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty && _selectedImageFiles.isEmpty) return;

    final conversationRef = FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.conversationId);

    List<Map<String, dynamic>> attachments = [];

    for (final file in _selectedImageFiles) {
      final fileName = file.path.split('/').last;
      final ref = FirebaseStorage.instance
          .ref()
          .child('chat_attachments/${widget.conversationId}/$fileName');

      final uploadTask = await ref.putFile(file);
      final fileUrl = await uploadTask.ref.getDownloadURL();

      attachments.add({
        'fileUrl': fileUrl,
        'fileName': fileName,
        'type': _pendingFileType,
      });
    }

    final msgRef = conversationRef.collection('messages').doc();

    await msgRef.set({
      'text': text,
      'isUser': true,
      'senderName': widget.patientName,
      'timestamp': FieldValue.serverTimestamp(),
      'readByDoctor': false,
      'readByUser': true,
      'readByDoctorAt': null,
      'readByUserAt': FieldValue.serverTimestamp(),
      if (attachments.isNotEmpty) 'attachments': attachments,
    });

    await conversationRef.update({
      'lastMessage': text.isNotEmpty
          ? text
          : _pendingFileType == 'pdf'
          ? '📄 ملف PDF'
          : '🖼️ صورة مرفقة',
      'lastSenderId': 'user',
      'updatedAt': FieldValue.serverTimestamp(),
      'lastMessageReadByUser': true,
      'lastMessageReadByDoctor': false,
      'unreadCountForDoctor': FieldValue.increment(1),
    });

    setState(() {
      _controller.clear();
      _selectedImageFiles.clear();
      _pendingFileType = null;
    });
  }

  void _showAttachmentOptions() {
    final local = AppLocalizations.of(context)!;
    final isLimitReached = _selectedImageFiles.length >= 8;

    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 8.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  enabled: !isLimitReached,
                  leading: Icon(
                    Icons.camera_alt,
                    color: isLimitReached ? Colors.grey : AppColors.main,
                    size: 22.sp,
                  ),
                  title: Row(
                    children: [
                      Text(
                        local.takePhoto,
                        style: AppTextStyles.getText2(context).copyWith(
                          fontSize: 12.sp,
                          color: isLimitReached ? Colors.grey : Colors.black,
                        ),
                      ),
                      if (isLimitReached) ...[
                        SizedBox(width: 6.w),
                        Text(
                          '(${local.maxImagesReached})',
                          style: AppTextStyles.getText3(context).copyWith(
                            fontSize: 10.sp,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ],
                  ),
                  onTap: isLimitReached
                      ? null
                      : () async {
                    Navigator.pop(context);
                    final picked = await ImagePicker().pickImage(source: ImageSource.camera);
                    if (picked != null && _selectedImageFiles.length < 8) {
                      _prepareFilePreview(File(picked.path), 'image');
                    }
                  },
                ),

                ListTile(
                  enabled: !isLimitReached,
                  leading: Icon(Icons.photo_library, color: isLimitReached ? Colors.grey : AppColors.main, size: 22.sp),
                  title: Row(
                    children: [
                      Text(
                        local.chooseFromLibrary,
                        style: AppTextStyles.getText2(context).copyWith(
                          fontSize: 12.sp,
                          color: isLimitReached ? Colors.grey : Colors.black,
                        ),
                      ),
                      if (isLimitReached) ...[
                        SizedBox(width: 6.w),
                        Text(
                          '(${local.maxImagesReached})',
                          style: AppTextStyles.getText3(context).copyWith(
                            fontSize: 10.sp,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ],
                  ),
                  onTap: isLimitReached
                      ? null
                      : () async {
                    Navigator.pop(context);

                    final remaining = 8 - _selectedImageFiles.length;
                    final result = await FilePicker.platform.pickFiles(
                      type: FileType.image,
                      allowMultiple: true,
                      withData: false,
                    );

                    if (result != null && result.files.isNotEmpty) {
                      final pickedFiles = result.files
                          .where((file) => file.path != null)
                          .map((file) => File(file.path!))
                          .toList();

                      final newFiles = pickedFiles.where((newFile) =>
                      !_selectedImageFiles.any((existing) => existing.path == newFile.path)).toList();

                      if (newFiles.length > remaining) {
                        // ✋ لا تضف شيء، فقط أعرض رسالة
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${AppLocalizations.of(context)!.maxImagesReached} ($remaining ${AppLocalizations.of(context)!.remaining})',
                            ),
                          ),
                        );
                        return;
                      }

                      // ✅ أضف الملفات فقط لو ضمن الحد المسموح
                      _prepareMultipleFilePreviews(newFiles, 'image');
                    }
                  },

                ),
                ListTile(
                  enabled: _selectedImageFiles.isEmpty,
                  leading: Icon(
                    Icons.picture_as_pdf,
                    color: _selectedImageFiles.isEmpty ? AppColors.main : Colors.grey,
                    size: 22.sp,
                  ),
                  title: Text(
                    local.uploadPdf,
                    style: AppTextStyles.getText2(context).copyWith(
                      fontSize: 12.sp,
                      color: _selectedImageFiles.isEmpty ? Colors.black : Colors.grey,
                    ),
                  ),
                  onTap: _selectedImageFiles.isEmpty
                      ? () async {
                    Navigator.pop(context);
                    final result = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['pdf'],
                    );
                    if (result != null && result.files.isNotEmpty) {
                      final file = File(result.files.first.path!);
                      _prepareFilePreview(file, 'pdf'); // ✅ ضروري للمعاينة
                      // _uploadFile(file, 'pdf');
                    }

                  }
                      : null,
                ),
                SizedBox(height: 8.h),
              ],
            ),
          ),
        );
      },
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

    print('🧪 Attachments count: ${_selectedImageFiles.length}');
    print('🧪 Pending file type: $_pendingFileType');
    print('🧪 File paths: ${_selectedImageFiles.map((e) => e.path).toList()}');


    if (_selectedImageFiles.isEmpty) return const SizedBox();

    final isPdf = _pendingFileType == 'pdf';



    print('🧪 isPdf resolved: $isPdf');

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


    print('🧪 Rendering image preview');

    // ✅ فقط في حال لم يكن PDF، نعرض الصور
    // الكود التالي لعرض الصور كما هو بعد هذا التعليق


    // ✅ باقي الحالات: صورة
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
    return SafeArea(
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: SizedBox(
            height: 55.h,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.grayMain.withOpacity(0.15),
                border: Border(top: BorderSide(color: Colors.grey.shade300, width: 0.5)),
              ),
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
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
                    Container(
                      constraints: BoxConstraints(maxWidth: 0.6.sw),
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
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
                              pdfs.first['fileName'] ?? 'PDF File',
                              style: AppTextStyles.getText2(context),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.open_in_new, size: 18.sp),
                            onPressed: () {
                              launchUrl(Uri.parse(pdfs.first['fileUrl']));
                            },
                          ),
                        ],
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
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12.r),
                      child: GestureDetector(
                        onTap: () => _showImageOverlay(images.map((e) => e['fileUrl'] as String).toList()),
                        child: Container(
                          constraints: BoxConstraints(maxWidth: 0.6.sw),
                          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 15.h),
                          decoration: BoxDecoration(
                            color: AppColors.main.withOpacity(0.08),
                            border: Border.all(color: AppColors.main.withOpacity(0.4)),
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
                                final imageUrl = images[i]['fileUrl'];

                                if (i == 3 && images.length > 4) {
                                  return GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _expandedImageUrls = images.map((e) => e['fileUrl'] as String).toList();
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
                                            '+${images.length - 3}',
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
                                        images.map((e) => e['fileUrl'] as String).toList(),
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
                          time != null ? intl.DateFormat('HH:mm').format(time) : '',
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

  Widget _buildTextBubble(String content, List<Map<String, dynamic>> attachments, bool isUser, Widget avatar, bool showReason, DateTime? time, bool isArabic) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 1, sigmaY: 1),
        child: Container(
          constraints: BoxConstraints(maxWidth: 0.7.sw),
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
              Row(children: [avatar, SizedBox(width: 8.w), Text(widget.accountHolderName, style: AppTextStyles.getText2(context).copyWith(color: isUser ? Colors.white : Colors.black, fontWeight: FontWeight.bold))]),
              SizedBox(height: 10.h),
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
                  time != null ? intl.DateFormat('HH:mm').format(time) : '',
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final isForRelative = widget.patientName != widget.accountHolderName;
    final lang = Localizations.localeOf(context).languageCode;
    final local = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.main,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.chevron_left, color: Colors.white, size: 28.sp),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18.r,
              backgroundColor: AppColors.whiteText.withOpacity(0.35),
              backgroundImage: AssetImage(widget.doctorImage),
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
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('conversations')
                  .doc(widget.conversationId)
                  .collection('messages')
                  .orderBy('timestamp')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final messages = snapshot.data!.docs;


                if (!_expandedImageOverlay && _selectedImageFiles.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_scrollController.hasClients) {
                      _scrollController.animateTo(
                        _scrollController.position.maxScrollExtent,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    }
                  });
                }



                // ✅ تحديث حالة القراءة إذا كانت الرسالة الأخيرة مرسلة من الطبيب
                if (messages.isNotEmpty) {
                  final lastMsg = messages.last.data() as Map<String, dynamic>;
                  final lastMsgRef = messages.last.reference;
                  final isUser = lastMsg['isUser'] ?? false;
                  final alreadyRead = lastMsg['readByUser'] == true;
                  bool hasUnread = false;

                  int unreadCount = 0;
                  for (final doc in snapshot.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final isUser = data['isUser'] ?? false;
                    final alreadyRead = data['readByUser'] == true;

                    if (!isUser && !alreadyRead) {
                      doc.reference.update({
                        'readByUser': true,
                        'readByUserAt': FieldValue.serverTimestamp(),
                      });
                      unreadCount++;
                    }
                  }

                  if (unreadCount > 0) {
                    FirebaseFirestore.instance
                        .collection('conversations')
                        .doc(widget.conversationId)
                        .update({
                      'lastMessageReadByUser': true,
                      'unreadCountForUser': 0, // 👈 ضروري لتحديث الحالة في MessagesPage
                    });
                  }



                }



                // ✅ ثاني شيء: تحديد إذا الطبيب رد
                final doctorHasReplied = messages.any((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['isUser'] == false;
                });


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
                          bottom: _selectedImageFiles.isNotEmpty ? 125.h : 65.h,
                        ),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final msg = messages[index].data() as Map<String, dynamic>;
                          final isUser = msg['isUser'] ?? false;
                          final content = msg['text'] ?? '';
                          final attachments = (msg['attachments'] as List?)?.cast<Map<String, dynamic>>() ?? [];
                          final timestamp = msg['timestamp'] as Timestamp?;
                          final time = timestamp?.toDate();
                          final readByDoctorAt = (msg['readByDoctorAt'] as Timestamp?)?.toDate();
                          final bool isReadByDoctor = isUser && (msg['readByDoctor'] == true);
                          final bool isLastRead = isReadByDoctor && (index == messages.length - 1);


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
                            backgroundImage: AssetImage(widget.doctorImage),
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
                            backgroundImage: AssetImage(widget.doctorImage),
                          );
                          final showReason = isUser && !firstUserMessageFound;
                          if (showReason) firstUserMessageFound = true;
                          final isArabic = _isArabicText(content);

                          // 🗓️ تحديد إذا كنا نحتاج إظهار فاصل اليوم
                          DateTime? currentDate = time != null ? DateTime(time.year, time.month, time.day) : null;
                          DateTime? previousDate;
                          if (index > 0) {
                            final previousTimestamp = (messages[index - 1].data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
                            final previousTime = previousTimestamp?.toDate();
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
                                              _buildTextBubble(content, attachments, isUser, avatar, showReason, time, isArabic),

                                            if (attachments.isNotEmpty)
                                              Padding(
                                                padding: EdgeInsets.only(top: 6.h),
                                                child: _buildAttachmentBubble(attachments, isUser, avatar2, time, showSenderName: content.trim().isEmpty &&
                                                    (index == 0 || messages[index - 1]['isUser'] != isUser)),
                                              ),

                                            if (isLastRead) ...[
                                              SizedBox(height: 4.h,),
                                              Align(
                                                alignment: lang == 'ar' ? Alignment.centerRight : Alignment.centerLeft,
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    CircleAvatar(
                                                      radius: 7.r,
                                                      backgroundImage: AssetImage(widget.doctorImage),
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
                                            ],                                          ],
                                        ),
                                      ),

                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );

                        },
                      ),
                    ),
                    if (!widget.isClosed && doctorHasReplied && _selectedImageFiles.isNotEmpty)
                      Positioned(
                        bottom: 55.h,
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

            if (isForRelative)
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
                              if (!_showAsGrid)
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
                                            child:IconButton(
                                              icon: _isDownloadingSingle
                                                  ? SizedBox(
                                                width: 16.sp,
                                                height: 16.sp,
                                                child: CircularProgressIndicator(
                                                  color: Colors.white,
                                                  strokeWidth: 2,
                                                ),
                                              )
                                                  : Icon(Icons.download, color: Colors.white, size: 16.sp),
                                              onPressed: _isDownloadingSingle
                                                  ? null
                                                  : () async {
                                                setState(() => _isDownloadingSingle = true);
                                                try {
                                                  final url = _expandedImageUrls[_initialImageIndex];
                                                  await GallerySaver.saveImage(url);
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Text(AppLocalizations.of(context)!.downloadCompleted),
                                                      backgroundColor: AppColors.main.withOpacity(0.9),
                                                    ),
                                                  );
                                                } catch (_) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Text(AppLocalizations.of(context)!.downloadFailed),
                                                      backgroundColor: AppColors.red.withOpacity(0.9),
                                                    ),
                                                  );
                                                } finally {
                                                  if (mounted) setState(() => _isDownloadingSingle = false);
                                                }
                                              },

                                            )


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
                                      GestureDetector(
                                        onTap: _isDownloadingAll
                                            ? null
                                            : () async {
                                          setState(() => _isDownloadingAll = true);
                                          try {
                                            for (final url in _expandedImageUrls) {
                                              await GallerySaver.saveImage(url);
                                            }
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('${_expandedImageUrls.length} ${AppLocalizations.of(context)!.imagesDownloadedSuccessfully}'),
                                                backgroundColor: AppColors.main.withOpacity(0.9),
                                              ),
                                            );
                                          } catch (_) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(AppLocalizations.of(context)!.imagesDownloadFailed),
                                                backgroundColor: AppColors.red.withOpacity(0.9),
                                              ),
                                            );
                                          } finally {
                                            if (mounted) setState(() => _isDownloadingAll = false);
                                          }
                                        },

                                        child: Container(
                                          padding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 12.h),
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
                                      )                                    ],
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



          ],
    ),
    );
  }
}
