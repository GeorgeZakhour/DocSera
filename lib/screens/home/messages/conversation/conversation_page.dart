import 'dart:io';
import 'package:docsera/utils/time_utils.dart';
import 'dart:ui';
import 'package:docsera/Business_Logic/Messages_page/conversation_cubit.dart';
import 'package:docsera/Business_Logic/Messages_page/conversation_state.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/screens/home/messages/conversation/services/chat_image_compression.dart';
import 'package:docsera/screens/home/messages/conversation/services/chat_scroll_controller.dart';
import 'package:docsera/screens/home/messages/conversation/widgets/closed_banner.dart';
import 'package:docsera/screens/home/messages/conversation/widgets/relative_banner.dart';
import 'package:docsera/screens/home/messages/conversation/widgets/input_bar.dart';
import 'package:docsera/screens/home/messages/conversation/widgets/attachments_preview_bar.dart';
import 'package:docsera/screens/home/messages/conversation/widgets/image_overlay_viewer.dart';
import 'package:docsera/screens/home/messages/conversation/widgets/messages_list_view.dart';
import 'package:docsera/screens/home/messages/conversation/widgets/message_skeleton.dart';
import 'package:docsera/screens/home/messages/conversation/services/chat_attachments_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../utils/full_page_loader.dart';

class ConversationPage extends StatefulWidget {
  final String conversationId;
  final String doctorName;
  final String patientName;
  final String accountHolderName;
  final ImageProvider doctorAvatar;

  const ConversationPage({
    super.key,
    required this.conversationId,
    required this.doctorName,
    required this.patientName,
    required this.accountHolderName,
    required this.doctorAvatar,
  });

  @override
  State<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends State<ConversationPage> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  final _picker = ImagePicker();
  final _compressor = ChatImageCompressor();
  late final ChatAttachmentsService _attachmentsService;

  final List<File> _pendingImages = [];
  File? _pendingPdf;
  int _imagesLoadingCount = 0; // ✅ Track loading images

  bool _autoScroll = true;
  OverlayEntry? _imageOverlay;

  @override
  void initState() {
    super.initState();

    _attachmentsService = ChatAttachmentsService(Supabase.instance.client);

    context.read<ConversationCubit>().start(widget.conversationId);

    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _imageOverlay?.remove();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // SCROLL HANDLING
  // ---------------------------------------------------------------------------

  void _handleScroll() {
    if (!_scrollController.hasClients) return;

    final atBottom = ChatScrollHelper.isAtBottom(_scrollController);

    if (atBottom && !_autoScroll) {
      _autoScroll = true;
    } else if (!atBottom && _autoScroll) {
      _autoScroll = false;
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_autoScroll && _scrollController.hasClients) {
        ChatScrollHelper.animateToBottom(_scrollController);
      }
    });
  }

  // ---------------------------------------------------------------------------
  // PICK ATTACHMENTS
  // ---------------------------------------------------------------------------

  Future<void> _pickImages() async {
    const int maxImages = 8;
    if (_pendingImages.length >= maxImages) {
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text("Maximum 8 images allowed.", style: TextStyle(color: Colors.white)), backgroundColor: Colors.red),
       );
       return;
    }

    // ✅ Use FilePicker for instant selection (no compression/copy delay)
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );

    if (result == null || result.files.isEmpty) return;

    List<File> newFiles = result.files.map((f) => File(f.path!)).toList();

    // Check Limit
    if (_pendingImages.length + newFiles.length > maxImages) {
       final allowed = maxImages - _pendingImages.length;
       newFiles = newFiles.take(allowed).toList();
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text("Limit reached. Only 8 images allowed.", style: TextStyle(color: Colors.white)), backgroundColor: Colors.orange),
       );
    }

    // ✅ Show shimmer immediately
    setState(() => _imagesLoadingCount = newFiles.length);
    
    // Force UI render frame
    await Future.delayed(const Duration(milliseconds: 50));

    final compressed = await _compressor.compress(newFiles);

    setState(() {
      _pendingImages.addAll(compressed);
      _imagesLoadingCount = 0;
    });
  }

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result == null || result.files.isEmpty) return;

    setState(() => _pendingPdf = File(result.files.first.path!));
  }

  void _clearAttachments() {
    setState(() {
      _pendingImages.clear();
      _pendingPdf = null;
    });
  }

  // ---------------------------------------------------------------------------
  // SEND MESSAGE
  // ---------------------------------------------------------------------------

  Future<void> _send() async {
    final cState = context.read<ConversationCubit>().state;

    if (cState.isConversationClosed || cState.isBlocked) {
      return; // منع إرسال الرسائل عند الإغلاق أو الحظر
    }

    final text = _textController.text.trim();
    final sendingImages = List<File>.from(_pendingImages);
    final sendingPdf = _pendingPdf;

    if (text.isEmpty && sendingImages.isEmpty && sendingPdf == null) return;

    _textController.clear();
    _clearAttachments();

    // ✅ Use Cubit's True Optimistic sending
    await context.read<ConversationCubit>().sendMediaMessage(
      conversationId: widget.conversationId,
      senderName: widget.accountHolderName,
      text: text,
      images: sendingImages,
      pdf: sendingPdf,
    );

    _scrollToBottom();
  }

  // ---------------------------------------------------------------------------
  // IMAGE OVERLAY
  // ---------------------------------------------------------------------------

  void _openImagesOverlay(
      List<String> urls, {
        int initialIndex = 0,
        bool showAsGrid = false,
      }) {
    _imageOverlay?.remove();

    _imageOverlay = OverlayEntry(
      builder: (_) => ImageOverlayViewer(
        imageUrls: urls,
        initialIndex: initialIndex,
        onAddToDocuments: (paths) async {
          // TODO: connect with your documents feature
        },
        onClose: () {
          _imageOverlay?.remove();
          _imageOverlay = null;
        },
      ),
    );

    Overlay.of(context, rootOverlay: true).insert(_imageOverlay!);
  }


  Widget _attachmentIcon({
    required String icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(14.r),
            decoration: BoxDecoration(
              color: AppColors.main.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: SvgPicture.asset(icon, width: 26.sp, height: 26.sp),
          ),
          SizedBox(height: 6.h),
          Text(label,
              style: AppTextStyles.getText3(context)
                  .copyWith(fontSize: 10.sp, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildBottomBanner(BuildContext context, String text) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: 12.h,   // مسافة عن الأسفل
        left: 16.w,     // مسافة الجوانب
        right: 16.w,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.r),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.55),
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: AppColors.main,
                width: 1, // الحد الرقيق حول كل الأطراف
              ),
            ),
            child: DefaultTextStyle(
              style: AppTextStyles.getText2(context).copyWith(
                fontSize: 12.sp,
                fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily ?? 'Cairo',
                color: AppColors.mainDark,
                decoration: TextDecoration.none,
              ),
              child: Center(child: Text(text, textAlign: TextAlign.center)),
            ),
          ),
        ),
      ),
    );
  }


  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final chatState = context.watch<ConversationCubit>().state;
    final local = AppLocalizations.of(context)!;

    final bool doctorHasReplied = chatState.hasDoctorResponded;

    final bool isDisabled = chatState.isConversationClosed || chatState.isBlocked;


    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.main,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 16),
            ),

            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.white.withOpacity(0.25),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(50),
                child: Image(image: widget.doctorAvatar, width: 32, height: 32),
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: Text(
                widget.doctorName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.getTitle2(context).copyWith(
                  color: Colors.white,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),

      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset("assets/images/Chat-BG.webp", fit: BoxFit.cover),
          ),

          Column(
            children: [
              if (widget.patientName != widget.accountHolderName)
                RelativeBanner(patientName: widget.patientName),

              if (chatState.isConversationClosed)
                ClosedBanner(doctorName: widget.doctorName),

              // Chat Area (List + Input)
              Expanded(
                child: Stack(
                  children: [
                    // 1. Messages List (Behind)
                    BlocConsumer<ConversationCubit, ConversationState>(
                       listener: (context, state) {
                         if (state.messages.isNotEmpty && _autoScroll) {
                           // Use jumpTo for initial load to prevent "scrolling down" animation
                           // if it's the very first load or drastically different,
                           // but here we just animate or jump based on needs.
                           // For smoothness, if users expect to see bottom immediately:
                           WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (_scrollController.hasClients) {
                                // Logic: If we are at the top (offset 0) and list is large, jump.
                                // Otherwise animate. But simplistic approach:
                                ChatScrollHelper.animateToBottom(_scrollController);
                              }
                           });
                         }
                       },
                       builder: (context, state) {
                         if (state.isLoading) {
                           return ListView.builder(
                               padding: EdgeInsets.symmetric(vertical: 20.h),
                               itemCount: 8,
                               itemBuilder: (context, index) {
                                 return MessageSkeleton(isUser: index % 2 == 0);
                               },
                             );
                         }

                         // Initial Jump to Bottom on first build if needed
                         if (state.messages.isNotEmpty ) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                               if (_scrollController.hasClients && _scrollController.position.pixels == 0) {
                                  ChatScrollHelper.jumpToBottom(_scrollController);
                               }
                            });
                         }

                         // ✅ OPTIMISTIC: Merge Server Messages + Pending Messages
                         // Server messages are stream-ordered (Oldest -> Newest).
                         // Pending messages are appended (Newest).
                         // Correct Order: [...Server, ...Pending]
                         final allMessages = [...state.messages, ...state.pendingMessages];

                         return MessagesListView(
                             messages: allMessages, // ✅ Pass merged list
                             pendingCount: 0,
                             pendingBuilder: (_, __) => const SizedBox(),
                             scrollController: _scrollController,
                             doctorName: widget.doctorName,
                             accountHolderName: widget.accountHolderName,
                             patientName: widget.patientName,
                             doctorImage: widget.doctorAvatar,
                             resolveImageUrls: (images) =>
                                 _attachmentsService.resolveImageUrls(images),
                             onOpenImages: _openImagesOverlay,
                             onRetry: (failedMsg) { // ✅ Handle Retry
                               context.read<ConversationCubit>().retryMessage(failedMsg);
                             },
                           );
                       },
                     ),

                    // 2. Bottom Elements (Floating on top)
                     Align(
                      alignment: Alignment.bottomCenter,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                           // Logic: Show Input Bar ONLY if conversation is open AND doctor has replied (or logic permits)
                           // User requested: "dont show the input bar when other bar appears"
                           
                           if (!isDisabled && doctorHasReplied) ...[
                             AttachmentsPreviewBar(
                               files: _pendingPdf != null ? [_pendingPdf!] : _pendingImages,
                               type: _pendingPdf != null ? 'pdf' : 'image',
                               loadingCount: _pendingPdf != null ? 0 : _imagesLoadingCount,
                               onClear: _clearAttachments,
                             ),
                             InputBar(
                               controller: _textController,
                               isEnabled: true,
                               hasAttachments: _pendingImages.isNotEmpty || _pendingPdf != null,
                               onSend: _send,
                               onSendAudio: (path, duration) async {
                                 final file = File(path);
                                 if (!await file.exists()) return;
                                 
                                 final cubit = context.read<ConversationCubit>();
                                 final service = cubit.service;
                                 
                                 final name = "${DocSeraTime.nowUtc().millisecondsSinceEpoch}_audio.m4a";
                                 final uploaded = await service.uploadAttachmentFile(
                                   conversationId: widget.conversationId,
                                   file: file,
                                   type: 'audio',
                                   storageName: name,
                                 );

                                 // ✅ Add duration metadata (seconds)
                                 uploaded['duration'] = duration.inSeconds;
                                 
                                 await cubit.sendMessage(
                                   conversationId: widget.conversationId,
                                   senderName: widget.accountHolderName,
                                   text: '',
                                   attachments: [uploaded],
                                 );
                                 
                                 _scrollToBottom();
                               },
                               onAddAttachment: () async {
                                 showModalBottomSheet(
                                   context: context,
                                   backgroundColor: Colors.white.withOpacity(0.0),
                                   shape: const RoundedRectangleBorder(
                                     borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                                   ),
                                   builder: (_) {
                                     return ClipRRect(
                                       borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                                       child: BackdropFilter(
                                         filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                                         child: Container(
                                           height: 200.h,
                                           padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 22.h),
                                           decoration: BoxDecoration(
                                             color: Colors.white.withOpacity(0.65),
                                             borderRadius:
                                             const BorderRadius.vertical(top: Radius.circular(20)),
                                           ),
                                           child: Column(
                                             mainAxisSize: MainAxisSize.min,
                                             children: [
                                               Text(local.chooseAttachmentType,
                                                   style: AppTextStyles.getTitle2(context)
                                                       .copyWith(fontSize: 12.sp, color: AppColors.grayMain)),
                                               SizedBox(height: 14.h),
                                               Divider(color: Colors.grey.shade300),
                                               SizedBox(height: 26.h),
       
                                               Row(
                                                 mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                                 children: [
                                                   _attachmentIcon(
                                                     icon: 'assets/icons/camera.svg',
                                                     label: local.takePhoto,
                                                     onTap: () async {
                                                       Navigator.pop(context);
                                                       final picked = await ImagePicker()
                                                           .pickImage(source: ImageSource.camera);
                                                       if (picked != null) {
                                                         _pendingImages.add(File(picked.path));
                                                         setState(() {});
                                                       }
                                                     },
                                                   ),
                                                   _attachmentIcon(
                                                     icon: 'assets/icons/gallery.svg',
                                                     label: local.chooseFromLibrary2,
                                                     onTap: () async {
                                                       Navigator.pop(context);
                                                       await _pickImages();
                                                     },
                                                   ),
                                                   _attachmentIcon(
                                                     icon: 'assets/icons/file.svg',
                                                     label: local.chooseFile,
                                                     onTap: () async {
                                                       Navigator.pop(context);
                                                       await _pickPdf();
                                                     },
                                                   ),
                                                 ],
                                               ),
                                             ],
                                           ),
                                         ),
                                       ),
                                     );
                                   },
                                 );
                               },
                             ),
                           ],
                           
                           // Banners (Exclusive)
                           if (!doctorHasReplied && !isDisabled)
                             _buildBottomBanner(context, local.waitingDoctorReply),
                             
                           if (isDisabled)
                             _buildBottomBanner(context, local.conversationClosed),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (_imageOverlay != null) Positioned.fill(child: Container()),
        ],
      ),
    );
  }
}
