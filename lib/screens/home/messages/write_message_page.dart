import 'dart:io';
import 'dart:ui';

import 'package:docsera/Business_Logic/Messages_page/conversation_cubit.dart';
import 'package:docsera/Business_Logic/Messages_page/messages_cubit.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/models/document.dart';
import 'package:docsera/models/patient_profile.dart';
import 'package:docsera/services/supabase/supabase_conversation_service.dart';
import 'package:docsera/widgets/base_scaffold.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:flutter_svg/svg.dart';
import 'package:image_picker/image_picker.dart';import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'conversation/conversation_page.dart';

class WriteMessagePage extends StatefulWidget {
  final String doctorName;
  final ImageProvider doctorImage;
  final String doctorImageUrl;
  final String doctorSpecialty;
  final String doctorTitle;
  final String doctorGender;
  final String selectedReason;
  final PatientProfile patientProfile;
  final UserDocument? attachedDocument;

  const WriteMessagePage({
    super.key,
    required this.doctorName,
    required this.doctorImage,
    required this.doctorImageUrl,
    required this.doctorSpecialty,
    required this.doctorTitle,
    required this.doctorGender,
    required this.selectedReason,
    required this.patientProfile,
    this.attachedDocument,

  });

  @override
  State<WriteMessagePage> createState() => _WriteMessagePageState();
}

class _WriteMessagePageState extends State<WriteMessagePage> {
  final TextEditingController _controller = TextEditingController();
  int charCount = 0;
  List<File> _selectedImageFiles = [];
  String? _pendingFileType;
  final bool _showAllAttachments = false;
  UserDocument? _attachedDocument;
  bool _expandedImageOverlay = false;
  List<String> _expandedImageUrls = [];
  int _initialImageIndex = 0;
  final bool _shouldAutoScroll = true;
  bool _isSending = false;


  void _showHelpBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (_) {
        return FractionallySizedBox(
          heightFactor: 0.5,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)!.helpTitle,
                        style: AppTextStyles.getTitle1(context).copyWith(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close),
                    )
                  ],
                ),
                SizedBox(height: 40.h),
                Image.asset("assets/images/message.png", height: 80.h),
                SizedBox(height: 40.h),
                Text(
                  AppLocalizations.of(context)!.helpMessage1,
                  style: AppTextStyles.getText2(context).copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 12.h),
                Text(
                  AppLocalizations.of(context)!.helpMessage2,
                  style: AppTextStyles.getText2(context).copyWith(color: Colors.grey.shade700),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAttachmentOptions() {
    final local = AppLocalizations.of(context)!;
    final imagesCount = _selectedImageFiles.length;
    final isImageMode = _pendingFileType == 'image';

    final isPdfOptionDisabled = isImageMode && imagesCount > 0;
    final isCameraDisabled = isImageMode && imagesCount >= 8;
    final isGalleryDisabled = isImageMode && imagesCount >= 8;

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
                local.chooseAttachmentType,
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
                    label: local.takePhoto,
                    onTap: isCameraDisabled
                        ? null
                        : () async {
                      Navigator.pop(context);
                      final picked = await ImagePicker().pickImage(source: ImageSource.camera);
                      if (picked != null) {
                        setState(() {
                          _selectedImageFiles.add(File(picked.path));
                          _pendingFileType = 'image';
                          _attachedDocument = null;
                        });
                      }
                    },
                  ),
                  _buildIconAction(
                    iconPath: 'assets/icons/gallery.svg',
                    label: local.chooseFromLibrary2,
                    onTap: isGalleryDisabled
                        ? null
                        : () async {
                      Navigator.pop(context);
                      final result = await FilePicker.platform.pickFiles(
                        type: FileType.image,
                        allowMultiple: true,
                      );
                      if (result != null && result.files.isNotEmpty) {
                        final pickedFiles = result.files
                            .where((file) => file.path != null)
                            .map((file) => File(file.path!))
                            .toList();

                        final totalFiles = _selectedImageFiles.length + pickedFiles.length;
                        final available = 8 - _selectedImageFiles.length;
                        final filesToAdd = pickedFiles.take(available).toList();

                        setState(() {
                          _selectedImageFiles.addAll(filesToAdd);
                          _pendingFileType = 'image';
                          _attachedDocument = null;
                        });
                      }
                    },
                  ),
                  _buildIconAction(
                    iconPath: 'assets/icons/file.svg',
                    label: local.chooseFile,
                    onTap: isPdfOptionDisabled
                        ? null
                        : () async {
                      Navigator.pop(context);
                      final result = await FilePicker.platform.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ['pdf'],
                      );
                      if (result != null && result.files.isNotEmpty) {
                        final pickedFile = File(result.files.first.path!);
                        setState(() {
                          _selectedImageFiles = [pickedFile];
                          _pendingFileType = 'pdf';
                          _attachedDocument = null;
                        });
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

  Widget _buildPreviewAttachment() {
    final local = AppLocalizations.of(context)!;

    if (_selectedImageFiles.isEmpty) return const SizedBox();
    final isPdf = _pendingFileType == 'pdf';

    Widget buildBlurredContainer(Widget child) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12.r),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              border: Border.all(color: AppColors.main.withOpacity(0.4)),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: child,
          ),
        ),
      );
    }

    if (isPdf) {
      final fileName = _selectedImageFiles.first.path.split('/').last;
      final shortName = fileName.length > 30 ? '${fileName.substring(0, 27)}...' : fileName;

      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 0, vertical: 6.h),
        child: buildBlurredContainer(
          Row(
            children: [
              SvgPicture.asset('assets/icons/pdf-file.svg', width: 24.sp, height: 24.sp),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  shortName,
                  style: AppTextStyles.getText2(context).copyWith(fontSize: 12.sp, color: Colors.black87),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, size: 18.sp, color: AppColors.main),
                onPressed: () {
                  setState(() {
                    _selectedImageFiles.clear();
                    _pendingFileType = null;
                  });
                },
              ),
            ],
          ),
        ),
      );
    }

    final count = _selectedImageFiles.length;
    final imageSize = 36.w;
    final spacing = 6.w;
    final label = count == 1 ? local.attachedImage : '$count ${local.attachedImages}';

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 0, vertical: 6.h),
      child: buildBlurredContainer(
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Wrap(
              spacing: spacing,
              children: List.generate(
                count > 3 ? 4 : count,
                    (i) {
                  if (i == 3 && count > 4) {
                    return Container(
                      width: imageSize,
                      height: imageSize,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300, width: 0.5),
                        borderRadius: BorderRadius.circular(6.r),
                        color: AppColors.main.withOpacity(0.15),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '+${count - 3}',
                        style: AppTextStyles.getText2(context).copyWith(
                          fontSize: 11.sp,
                          color: AppColors.main,
                        ),
                      ),
                    );
                  } else {
                    return Container(
                      width: imageSize,
                      height: imageSize,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300, width: 0.5),
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6.r),
                        child: GestureDetector(
                          onTap: () {
                            final filePaths = _selectedImageFiles.map((f) => f.path).toList();
                            _showLocalImageOverlayWithIndex(filePaths, i);
                          },
                          child: GestureDetector(
                            onTap: () {
                              final filePaths = _selectedImageFiles.map((f) => f.path).toList();
                              _showLocalImageOverlayWithIndex(filePaths, i);
                            },
                            child: Image.file(
                              _selectedImageFiles[i],
                              fit: BoxFit.cover,
                            ),
                          ),

                        ),

                      ),
                    );
                  }
                },
              ),
            ),
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
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showLocalImageOverlayWithIndex(List<String> paths, int index) {
    setState(() {
      _expandedImageUrls = paths;
      _initialImageIndex = index;
      _expandedImageOverlay = true;
    });
  }


  void _hideImageOverlay() {
    setState(() {
      _expandedImageOverlay = false;
    });
  }


  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      titleAlignment: 2,
      height: 75.h,
      title: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.background2.withOpacity(0.3),
            radius: 18.r,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(50),
              child: Image(image: widget.doctorImage, width: 40.w, height: 40.h, fit: BoxFit.cover),
            ),
          ),
          SizedBox(width: 15.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppLocalizations.of(context)!.sendMessage,
                  style: AppTextStyles.getText2(context).copyWith(fontSize: 12.sp, color: AppColors.whiteText)),
              Text(widget.doctorName,
                  style: AppTextStyles.getTitle2(context).copyWith(fontSize: 14.sp, color: AppColors.whiteText)),
            ],
          ),
        ],
      ),
      child: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  color: AppColors.main.withOpacity(0.6),
                  child: Padding(
                    padding: EdgeInsets.all(8.w),
                    child: Row(
                      children: [
                        Icon(Icons.mail_outline, size: 18.sp, color: AppColors.whiteText),
                        SizedBox(width: 8.w),
                        Text(widget.selectedReason,
                            style: AppTextStyles.getTitle1(context)
                                .copyWith(color: AppColors.whiteText, fontSize: 11.sp)),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 25.h),
                Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            AppLocalizations.of(context)!.whatDoYouNeed,
                            style: AppTextStyles.getTitle1(context).copyWith(fontSize: 12.sp),
                          ),
                          GestureDetector(
                            onTap: _showHelpBottomSheet,
                            child: Row(
                              children: [
                                Icon(Icons.help_outline, size: 16.sp, color: AppColors.main),
                                SizedBox(width: 4.w),
                                Text(
                                  AppLocalizations.of(context)!.help,
                                  style: AppTextStyles.getText2(context).copyWith(
                                    color: AppColors.main,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10.sp,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 10.h),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 15.w),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 10.h),
                            TextField(
                              controller: _controller,
                              maxLines: 5,
                              maxLength: 800,
                              onChanged: (value) {
                                setState(() => charCount = value.length);
                              },
                              style: AppTextStyles.getText2(context),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: AppLocalizations.of(context)!.messageHint,
                                hintStyle: AppTextStyles.getText3(context).copyWith(color: Colors.grey),
                                counterText: '',
                              ),
                            ),
                            SizedBox(height: 10.h),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text("$charCount/800",
                                  style: AppTextStyles.getText3(context).copyWith(color: Colors.grey)),
                            ),
                            SizedBox(height: 20.h),
                            GestureDetector(
                              onTap: _showAttachmentOptions,
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 3.h),
                                child: Row(
                                  children: [
                                    Icon(Icons.attach_file, size: 18.sp, color: AppColors.main),
                                    SizedBox(width: 6.w),
                                    Text(AppLocalizations.of(context)!.attachDocuments,
                                        style: AppTextStyles.getText3(context).copyWith(color: AppColors.main)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 10.h),
                      if (_selectedImageFiles.isNotEmpty || _attachedDocument != null)
                        _buildPreviewAttachment(),
                      SizedBox(height: 40.h),
                      ElevatedButton.icon(
                        onPressed: _isSending
                            ? null
                            : () async {
                          setState(() => _isSending = true);

                          final messageText = _controller.text.trim();
                          if (messageText.isEmpty) {
                            setState(() => _isSending = false);
                            return;
                          }

                          final patientId = widget.patientProfile.patientId;
                          final doctorId = widget.patientProfile.doctorId;

                          String accountHolderName = '';
                          final prefs = await SharedPreferences.getInstance();
                          accountHolderName = prefs.getString('userName') ?? '';

                          if (accountHolderName.isEmpty) {
                            final userId = prefs.getString('userId');
                            if (userId != null && userId.isNotEmpty) {
                              final response = await Supabase.instance.client
                                  .from('users')
                                  .select('first_name, last_name')
                                  .eq('id', userId)
                                  .maybeSingle();

                              if (response != null) {
                                final firstName = response['first_name'] ?? '';
                                final lastName = response['last_name'] ?? '';
                                accountHolderName = "$firstName $lastName".trim();
                              }
                            }
                          }

                          debugPrint("📸 doctorImageUrl before startConversation = ${widget.doctorImageUrl}");

                          final conversationId = await context.read<MessagesCubit>().startConversation(
                            patientId: patientId,
                            doctorId: doctorId,
                            message: messageText,
                            doctorName: widget.doctorName,
                            doctorSpecialty: widget.doctorSpecialty,
                            doctorImage: widget.doctorImageUrl,
                            doctorTitle: widget.doctorTitle,
                            doctorGender: widget.doctorGender,
                            patientName: widget.patientProfile.patientName,
                            accountHolderName: accountHolderName,
                            selectedReason: widget.selectedReason,
                          );

                          if (conversationId != null) {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BlocProvider(
                                  create: (_) => ConversationCubit(ConversationService()),
                                  child: ConversationPage(
                                    conversationId: conversationId,
                                    doctorName: widget.doctorName,
                                    patientName: widget.patientProfile.patientName,
                                    accountHolderName: accountHolderName,
                                    doctorAvatar: widget.doctorImage,
                                  ),
                                ),
                              ),
                              (route) => route.isFirst,
                            );
                          }

                          setState(() => _isSending = false);
                        },

                        icon: _isSending
                            ? const SizedBox()
                            : SvgPicture.asset(
                          "assets/icons/send.svg",
                          height: 18.sp,
                          colorFilter: const ColorFilter.mode(AppColors.whiteText, BlendMode.srcIn),
                        ),

                        label: _isSending
                            ? SizedBox(
                          width: 18.sp,
                          height: 18.sp,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                            : Text(
                          AppLocalizations.of(context)!.sendMyMessage,
                          style: AppTextStyles.getText2(context).copyWith(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.mainDark,
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          minimumSize: Size(double.infinity, 50.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_expandedImageOverlay)
            SizedBox.expand(
              child: Stack(
                children: [
                  // الخلفية المضببة
                  BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      color: AppColors.grayMain.withOpacity(0.4), // خلفية فاتحة مضببة
                    ),
                  ),

                  // الصور
                  Center(
                    child: Transform.translate(
                      offset: Offset(0, -50.h), // حرك الصور للأعلى 30.h
                      child: PageView.builder(
                        controller: PageController(initialPage: _initialImageIndex),
                        itemCount: _expandedImageUrls.length,
                        onPageChanged: (index) {
                          setState(() {
                            _initialImageIndex = index;
                          });
                        },
                        itemBuilder: (context, index) {
                          return Center(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16.r),
                              child: Image.file(
                                File(_expandedImageUrls[index]),
                                fit: BoxFit.contain,
                                width: MediaQuery.of(context).size.width * 0.85,
                                height: MediaQuery.of(context).size.height * 0.6,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  // زر الحذف الثابت بأسفل الشاشة
                  Positioned(
                    bottom: 50.h,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: GestureDetector(
                        onTap: () {
                          final pathToRemove = _expandedImageUrls[_initialImageIndex];
                          setState(() {
                            _selectedImageFiles.removeWhere((file) => file.path == pathToRemove);
                            _expandedImageUrls.removeAt(_initialImageIndex);

                            if (_expandedImageUrls.isEmpty) {
                              _expandedImageOverlay = false;
                              _pendingFileType = null;
                            } else {
                              _initialImageIndex = _initialImageIndex.clamp(0, _expandedImageUrls.length - 1);
                            }
                          });
                        },
                        child: ClipOval(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 10),
                            child: CircleAvatar(
                              radius: 28.r,
                              backgroundColor: AppColors.grayMain.withOpacity(0.4),
                              child: Icon(Icons.delete, color: Colors.white, size: 22.sp),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),


                  // زر الإغلاق
                  Positioned(
                    top: 20.h,
                    right: 20.w,
                    child: GestureDetector(
                      onTap: _hideImageOverlay,
                      child: Container(
                        width: 30.r,
                        height: 30.r,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.grayMain.withOpacity(0.7),
                        ),
                        child: Center(
                          child: Icon(Icons.close, color: AppColors.whiteText, size: 18.sp),
                        ),
                      ),
                    ),
                  ),

                ],
              ),
            ),



        ],
      ),
    );
  }
}
