import 'dart:ui';

import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/models/document.dart';
import 'package:docsera/screens/home/Document/document_preview_page.dart';
import 'package:docsera/utils/time_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart' as intl;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:docsera/screens/home/messages/conversation/widgets/audio_message_bubble.dart';
import 'package:docsera/screens/home/messages/conversation/widgets/resolved_bubbles.dart';
import 'package:docsera/screens/home/messages/conversation/widgets/decrypted_image_cache.dart';

import '../../../../../utils/full_page_loader.dart';

class MessagesListView extends StatelessWidget {
  final List<Map<String, dynamic>> messages;
  final int pendingCount;
  final Widget Function(BuildContext context, int pendingIndex) pendingBuilder;

  final ScrollController scrollController;

  final String doctorName;
  final String accountHolderName;
  final String patientName;
  final ImageProvider doctorImage;

  /// Resolve image URLs from attachments (bucket + paths OR file_url).
  final Future<List<String>> Function(List<Map<String, dynamic>> images)
  resolveImageUrls;

  /// Called when user taps an image / grid.
  final void Function(List<String> urls, {int initialIndex, bool showAsGrid, bool encrypted})
  onOpenImages;

  /// Called when user taps retry on a failed message
  final void Function(Map<String, dynamic> msg)? onRetry;

  /// Helper to resolve file URL (signed)
  final Future<String> Function(String bucket, String path)? resolveFileUrl;

  /// ✅ Task 16: Expiring media items for this conversation (from StorageQuotaService).
  /// Each entry: { 'id': String, 'message_id': String, 'expires_at': String, 'media_type': String }
  final List<Map<String, dynamic>> expiringMedia;

  const MessagesListView({
    super.key,
    required this.messages,
    required this.pendingCount,
    required this.pendingBuilder,
    required this.scrollController,
    required this.doctorName,
    required this.accountHolderName,
    required this.patientName,
    required this.doctorImage,
    required this.resolveImageUrls,
    required this.onOpenImages,
    this.onRetry,
    this.resolveFileUrl,
    this.expiringMedia = const [],
  });

  bool _isArabicText(String text) {
    return RegExp(r'[\u0600-\u06FF]').hasMatch(text);
  }

  // ✅ Task 16: Look up expiry info for a message by its ID.
  // Returns the expiry DateTime if found, null otherwise.
  DateTime? _expiryForMessage(String? messageId) {
    if (messageId == null || expiringMedia.isEmpty) return null;
    for (final item in expiringMedia) {
      if (item['message_id']?.toString() == messageId) {
        final expiresAt = item['expires_at']?.toString();
        if (expiresAt != null) return DateTime.tryParse(expiresAt);
      }
    }
    return null;
  }

  // Returns true if the given messageId has an expired entry in expiringMedia.
  // Checks the `expired` flag first (if present), otherwise compares `expires_at` to now.
  bool _isExpired(String? messageId) {
    if (messageId == null || expiringMedia.isEmpty) return false;
    for (final item in expiringMedia) {
      if (item['message_id']?.toString() == messageId) {
        if (item['expired'] == true) return true;
        final expiresAt = DateTime.tryParse(item['expires_at']?.toString() ?? '');
        if (expiresAt != null && expiresAt.isBefore(DateTime.now())) return true;
      }
    }
    return false;
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

  String _getDayLabel(DateTime date, BuildContext context) {
    // ✅ Use Syria Time for logic and formatting
    final syriaDate = DocSeraTime.toSyria(date);
    final now = DocSeraTime.nowSyria();
    
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(syriaDate.year, syriaDate.month, syriaDate.day);

    if (messageDate == today) {
      return AppLocalizations.of(context)!.today;
    } else if (messageDate == yesterday) {
      return AppLocalizations.of(context)!.yesterday;
    } else {
      return DocSeraTime.formatBusinessDate(context, syriaDate);
    }
  }

  String _formatReadTime(DateTime? date, BuildContext context) {
    if (date == null) return '';
    return DocSeraTime.format12hLocalized(context, date);
  }

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    final local = AppLocalizations.of(context)!;

    bool firstUserMessageFound = false;

    // ✅ FIX: Align short chats to TOP, but keep Bottom Anchoring for long chats
    // Align(topCenter) + shrinkWrap: true + reverse: true DOES this magic.
    return Align(
      alignment: Alignment.topCenter,
      child: ListView.builder(
        controller: scrollController,
        reverse: true,
        shrinkWrap: true, // Allow list to occupy only needed height
        physics: const AlwaysScrollableScrollPhysics(), // Ensure scrolling always works
        padding: EdgeInsets.only(
          left: 20.w,
          top: 12.h,
          right: 20.w,
          bottom: 110.h, // Bottom padding to clear floating input
        ),
        itemCount: messages.length + pendingCount,
        itemBuilder: (context, index) {
        // Pending shimmer messages (at the visual bottom, index 0..P-1)
        if (index < pendingCount) {
          // We want oldest pending at visual top of pending block (higher index)
          // Newest pending at visual bottom (index 0).
          // Assuming pendingBuilder expects index 0 as "First Pending".
          // Let's pass reverse index.
          return pendingBuilder(context, pendingCount - 1 - index);
        }

        final int msgVisualIndex = index - pendingCount;
        final int effectiveIndex = messages.length - 1 - msgVisualIndex;
        
        final msg = messages[effectiveIndex];
        final isUser = msg['is_user'] ?? false;
        final content = msg['text'] ?? '';
        final attachments =
            (msg['attachments'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final timestamp = DateTime.tryParse(msg['timestamp'] ?? '');
        final time = timestamp;

        final readByDoctorAt =
        DateTime.tryParse(msg['readByDoctorAt'] ?? '');
        final bool isReadByDoctor = isUser && (msg['read_by_doctor'] == true);

        // Last Read check (Newest message)
        final bool isLastRead =
            isReadByDoctor && (effectiveIndex == messages.length - 1);

        bool showSenderName = true;
        // Check Previous (Older) Message
        if (effectiveIndex > 0) {
          final prev = messages[effectiveIndex - 1];
          final prevSender = prev['is_user'] ?? false;
          if (prevSender == isUser) {
            showSenderName = false;
          }
        }

        final avatarUser = CircleAvatar(
          radius: 12.r,
          backgroundColor: AppColors.whiteText.withOpacity(0.6),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Transform.translate(
              offset: const Offset(0, -1.5),
              child: Text(
                _getInitials(accountHolderName),
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
        );

        final avatarUserSmall = CircleAvatar(
          radius: 6.r,
          backgroundColor: AppColors.main.withOpacity(0.8),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Transform.translate(
              offset: const Offset(0, -1.5),
              child: Text(
                _getInitials(accountHolderName),
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
        );

        final avatarDoctor = CircleAvatar(
          radius: 10.r,
          backgroundColor: AppColors.main.withOpacity(0.55),
          backgroundImage: doctorImage,
        );

        final avatarDoctorSmall = CircleAvatar(
          radius: 10.r,
          backgroundColor: AppColors.main.withOpacity(0.55),
          backgroundImage: doctorImage,
        );

        final avatar = isUser ? avatarUser : avatarDoctor;
        final avatar2 = isUser ? avatarUserSmall : avatarDoctorSmall;

        final showReason = isUser && !firstUserMessageFound;
        if (showReason) firstUserMessageFound = true;
        final isArabic = _isArabicText(content);

        DateTime? currentDate =
        time != null ? DateTime(time.year, time.month, time.day) : null;
        DateTime? previousDate;
        // Check Previous (Older) Message Date
        if (effectiveIndex > 0) {
          final previousTimestampString =
          (messages[effectiveIndex - 1])['timestamp'] as String?;
          final previousTime = previousTimestampString != null
              ? DateTime.tryParse(previousTimestampString)
              : null;
          if (previousTime != null) {
            previousDate = DateTime(
                previousTime.year, previousTime.month, previousTime.day);
          }
        }
        final showDateDivider =
            currentDate != null && currentDate != previousDate;

        return Padding(
          padding: EdgeInsets.only(bottom: 12.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (showDateDivider && time != null)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 10.h),
                  child: Row(
                    children: [
                      Expanded(
                        child: Divider(
                          color: Colors.grey.shade300,
                          thickness: 1,
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8.w),
                        child: Text(
                          _getDayLabel(time, context),
                          style: AppTextStyles.getText3(context).copyWith(
                            fontSize: 11.sp,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          color: Colors.grey.shade300,
                          thickness: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              Align(
                alignment:
                isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment:
                  isUser ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                  children: [
                    Align(
                      alignment:
                      isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: isUser
                            ? CrossAxisAlignment.start
                            : CrossAxisAlignment.end,
                        children: [
                          if (content.trim().isNotEmpty)
                            _buildTextBubble(
                              context: context,
                              content: msg['text'] ?? '',
                              attachments: (msg['attachments'] as List?)
                                  ?.cast<Map<String, dynamic>>() ??
                                  [],
                              isUser: isUser,
                              avatar: avatar,
                              showReason: showReason,
                              time: timestamp,
                              isArabic: _isArabicText(msg['text'] ?? ''),
                              showSenderName: showSenderName,
                              status: msg['status'] as String?,
                              onRetryTap: () => onRetry?.call(msg),
                              isReadByDoctor: isReadByDoctor,
                            ),
                          if (attachments.isNotEmpty)
                            Padding(
                              padding: EdgeInsets.only(top: 6.h),
                              child: _buildAttachmentBubble(
                                context: context,
                                attachments: attachments,
                                isUser: isUser,
                                avatar: avatar2,
                                time: time,
                                showSenderName: showSenderName,
                                status: msg['status'] as String?,
                                onRetryTap: () => onRetry?.call(msg),
                                messageId: msg['id']?.toString(),
                                isReadByDoctor: isReadByDoctor,
                              ),
                            ),
                          if (isLastRead) ...[
                            SizedBox(height: 4.h),
                            Align(
                              alignment: lang == 'ar'
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(
                                    radius: 7.r,
                                    backgroundImage: doctorImage,
                                    backgroundColor:
                                    AppColors.main.withOpacity(0.5),
                                  ),
                                  SizedBox(width: 4.w),
                                  Text(
                                    '${local.read} • ${_formatReadTime(readByDoctorAt, context)}',
                                    style: AppTextStyles.getText3(context)
                                        .copyWith(
                                      fontSize: 9.sp,
                                      color: Colors.grey,
                                    ),
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
      ),
    );
  }

  Widget _buildTextBubble({
    required BuildContext context,
    required String content,
    required List<Map<String, dynamic>> attachments,
    required bool isUser,
    required Widget avatar,
    required bool showReason,
    required DateTime? time,
    required bool isArabic,
    required bool showSenderName,
    String? status,
    VoidCallback? onRetryTap,
    bool isReadByDoctor = false,
  }) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 1, sigmaY: 1),
        child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: 0.15.sw,
              maxWidth: 0.6.sw,
            ),
            child: Container(
              padding:
              EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: isUser
                    ? AppColors.mainDark.withOpacity(0.9)
                    : AppColors.grayMain.withOpacity(0.25),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12.r),
                  topRight: Radius.circular(12.r),
                  bottomLeft:
                  isUser ? Radius.circular(12.r) : Radius.zero,
                  bottomRight:
                  isUser ? Radius.zero : Radius.circular(12.r),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showSenderName)
                    Row(
                      children: [
                        avatar,
                        SizedBox(width: 8.w),
                        Text(
                          isUser ? accountHolderName : doctorName,
                          style: AppTextStyles.getText3(context).copyWith(
                            color: isUser ? Colors.white : Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  if (showSenderName) SizedBox(height: 10.h),
                  Directionality(
                    textDirection:
                    isArabic ? TextDirection.rtl : TextDirection.ltr,
                    child: Text(
                      content,
                      style: AppTextStyles.getText3(context).copyWith(
                        color: isUser ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  SizedBox(height: 4.h),
                  if (attachments.isEmpty)
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            time != null
                                ? DocSeraTime.format12hLocalized(context, time)
                                : '',
                            style: AppTextStyles.getText3(context).copyWith(
                              fontSize: 10.sp,
                              color:
                              isUser ? Colors.white70 : Colors.black54,
                            ),
                          ),
                          if (isUser) ...[
                             SizedBox(width: 4.w),
                             if (status == 'sending')
                               SizedBox(
                                 width: 10.w, 
                                 height: 10.w,
                                 child: const CircularProgressIndicator(
                                   strokeWidth: 1.5, 
                                   color: Colors.white70,
                                 ),
                               )
                             else if (status == 'failed')
                               GestureDetector(
                                 onTap: onRetryTap,
                                 child: Icon(
                                   Icons.error_outline, 
                                   color: Colors.redAccent, 
                                   size: 14.sp,
                                 ),
                               )
                             else
                               Icon(
                                 Icons.done_all,
                                 color: isReadByDoctor ? AppColors.orange : Colors.white54,
                                 size: 14.sp,
                               ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
      ),
    );
  }

  // ✅ Task 16: Build a small expiry label shown below an attachment bubble.
  Widget _buildExpiryLabel(BuildContext context, DateTime expiryDate) {
    final local = AppLocalizations.of(context)!;
    final now = DocSeraTime.nowSyria();
    final diff = expiryDate.difference(now);
    final daysLeft = diff.inDays;

    final bool isUrgent = daysLeft <= 7;
    final Color labelColor = isUrgent ? Colors.red.shade600 : Colors.orange.shade700;

    final String text = daysLeft <= 0
        ? local.fileExpired
        : daysLeft <= 14
            ? local.expiresInDays(daysLeft)
            : local.expiresOn(DocSeraTime.formatBusinessDate(context, expiryDate));

    return Padding(
      padding: EdgeInsets.only(top: 3.h),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, color: labelColor, size: 11.sp),
          SizedBox(width: 3.w),
          Text(
            text,
            style: AppTextStyles.getText3(context).copyWith(
              fontSize: 9.sp,
              color: labelColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Task 16: Build a gray placeholder shown when a file has expired.
  Widget _buildExpiredPlaceholder(BuildContext context, {required String fileType}) {
    final local = AppLocalizations.of(context)!;
    return Container(
      constraints: BoxConstraints(minWidth: 0.3.sw, maxWidth: 0.6.sw),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 16.h),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            fileType == 'pdf' ? Icons.picture_as_pdf : Icons.image_not_supported,
            color: Colors.grey.shade400,
            size: 22.sp,
          ),
          SizedBox(width: 8.w),
          Text(
            local.fileExpired,
            style: AppTextStyles.getText3(context).copyWith(
              color: Colors.grey.shade500,
              fontSize: 11.sp,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentBubble({
    required BuildContext context,
    required List<Map<String, dynamic>> attachments,
    required bool isUser,
    required Widget avatar,
    required DateTime? time,
    required bool showSenderName,
    String? status,
    VoidCallback? onRetryTap,
    String? messageId,
    bool isReadByDoctor = false,
  }) {
    final images = attachments
        .where((a) => (a['type'] ?? a['file_type']) == 'image')
        .cast<Map<String, dynamic>>()
        .toList();

    final pdfs = attachments
        .where((a) => (a['type'] ?? a['file_type']) == 'pdf')
        .cast<Map<String, dynamic>>()
        .toList();

    final currentUserId =
        Supabase.instance.client.auth.currentUser?.id ?? '';

    // PDF only
    if (images.isEmpty && pdfs.isNotEmpty) {
      final pdf = pdfs.first;

      // ✅ Task 16: Determine expiry for this message.
      final expiryDate = _expiryForMessage(messageId);
      final isExpiredFile = _isExpired(messageId);

      return Align(
        alignment: isUser ? Alignment.centerLeft : Alignment.centerRight,
        child: Column(
          crossAxisAlignment:
          isUser ? CrossAxisAlignment.start : CrossAxisAlignment.end,
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
                      isUser ? accountHolderName : doctorName,
                      style: AppTextStyles.getText2(context).copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        fontSize: 12.sp,
                      ),
                    ),
                  ],
                ),
              ),
            // ✅ Task 16: Show expired placeholder instead of tappable bubble.
            if (isExpiredFile)
              _buildExpiredPlaceholder(context, fileType: 'pdf')
            else
              GestureDetector(
                onTap: () async {
                  // Old style: file_url / fileUrl
                  String? url = (pdf['file_url'] ?? pdf['fileUrl'])?.toString();
                  String? localPath = pdf['localPath']?.toString();

                  // Fallback: bucket + paths
                  if (url == null || url.trim().isEmpty) {
                    final bucket = (pdf['bucket'] ?? 'chat.attachments').toString();
                    final paths = (pdf['paths'] as List?) ?? [];

                    if (localPath != null && localPath.isNotEmpty) {
                       url = localPath;
                    } else if (paths.isNotEmpty) {
                      if (resolveFileUrl != null) {
                        url = await resolveFileUrl!(bucket, paths.first.toString());
                      } else {
                        // Fallback if no resolver provided
                        url = paths.first.toString();
                      }
                    } else {
                      return;
                    }
                  }

                  if (url == null || url.trim().isEmpty) return;

                  final userDoc = UserDocument(
                    id: '',
                    userId: currentUserId,
                    name: pdf['file_name'] ??
                        pdf['fileName'] ??
                        'PDF File',
                    type: '',
                    fileType: 'pdf',
                    patientId: patientName,
                    previewUrl: url,
                    pages: [url],
                    uploadedAt: DocSeraTime.nowUtc(),
                    uploadedById: '',
                    cameFromConversation: true,
                    conversationDoctorName: doctorName,
                    encrypted: pdf['encrypted'] == true,
                  );

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DocumentPreviewPage(
                        document: userDoc,
                        cameFromConversation: true,
                        doctorName: doctorName,
                        chatMediaId: pdf['id']?.toString(),
                      ),
                    ),
                  );
                },
                child: Container(
                  constraints:
                  BoxConstraints(minWidth: 0.3.sw, maxWidth: 0.6.sw),
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 20.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(
                      color: AppColors.main.withOpacity(0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      SvgPicture.asset(
                        'assets/icons/pdf-file.svg',
                        width: 20.w,
                        height: 20.w,
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          pdfs.first['file_name'] ??
                              pdfs.first['fileName'] ??
                              'PDF File',
                          style: AppTextStyles.getText2(context),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // ✅ Task 16: Expiry label below PDF bubble.
            if (!isExpiredFile && expiryDate != null)
              Align(
                alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: _buildExpiryLabel(context, expiryDate),
              ),
            Padding(
              padding: EdgeInsets.only(top: 2.h),
              child: Align(
                alignment: isUser
                    ? Alignment.bottomRight
                    : Alignment.bottomLeft,
                child: Padding(
                  padding: EdgeInsets.only(top: 1.h),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        time != null ? DocSeraTime.format12hLocalized(context, time) : '',
                        style: AppTextStyles.getText3(context).copyWith(
                          fontSize: 10.sp,
                          color: Colors.black54,
                          height: 1.0,
                        ),
                      ),
                      if (isUser) ...[
                        SizedBox(width: 4.w),
                        if (status == 'sending')
                          SizedBox(
                            width: 10.w,
                            height: 10.w,
                            child: const CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: AppColors.main,
                            ),
                          )
                        else if (status == 'failed')
                          GestureDetector(
                            onTap: onRetryTap,
                            child: Icon(
                              Icons.error_outline,
                              color: Colors.redAccent,
                              size: 14.sp,
                            ),
                          )
                        else
                          Icon(
                            Icons.done_all,
                            color: isReadByDoctor ? AppColors.orange : Colors.black38,
                            size: 14.sp,
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    
    // Audio
    final audios = attachments
        .where((a) => (a['type'] ?? a['file_type']) == 'audio' || (a['type'] ?? a['file_type']) == 'voice')
        .cast<Map<String, dynamic>>()
        .toList();
        
    if (audios.isNotEmpty) {
       final List<Widget> audioBubbles = [];
       
       for (final audio in audios) {
         String? url = (audio['file_url'] ?? audio['fileUrl'] ?? audio['publicUrl'])?.toString();
         String? localPath = audio['localPath']?.toString();
         final paths = (audio['paths'] as List?)?.cast<String>() ?? [];
         
         bool isImage(String? p) {
           if (p == null) return false;
           final low = p.toLowerCase();
           return low.endsWith('.jpg') || low.endsWith('.jpeg') || 
                  low.endsWith('.png') || low.endsWith('.webp');
         }

         String? remotePath;
         if (paths.isNotEmpty) {
           // ✅ Find the first path that is NOT an image
           remotePath = paths.firstWhere((p) => !isImage(p), orElse: () => "");
         }

         // ✅ CRITICAL: If both URL and paths point only to images, this attachment is likely just a waveform thumbnail.
         // Skip it to avoid rendering a broken audio bubble.
         if (isImage(url) && (remotePath == null || remotePath.isEmpty || isImage(remotePath))) {
            continue; 
         }

         final path = localPath ?? (remotePath != null && remotePath.isNotEmpty ? remotePath : null);
         final int? duration = audio['duration'];

         audioBubbles.add(
           Padding(
             padding: EdgeInsets.only(bottom: 6.h),
             child: ResolvedAudioBubble(
               url: (isImage(url)) ? null : url, // Protect against image URLs in the main field
               path: path,
               isUser: isUser,
               duration: duration,
             ),
           )
         );
       }

       if (audioBubbles.isNotEmpty) {
         final lang = Localizations.localeOf(context).languageCode;
         final isAr = lang == 'ar';

         return Align(
           alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
           child: Column(
             crossAxisAlignment: (isUser || isAr) ? CrossAxisAlignment.start : CrossAxisAlignment.end,
             children: [
               if (showSenderName)
                  Padding(
                    padding: EdgeInsets.only(bottom: 4.h),
                    child: Text(
                      isUser ? accountHolderName : doctorName,
                      style: AppTextStyles.getText2(context).copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        fontSize: 10.sp,
                      ),
                    ),
                  ),
               ...audioBubbles,
               Padding(
                 padding: EdgeInsets.only(top: 2.h),
                 child: Row(
                   mainAxisSize: MainAxisSize.min,
                   children: [
                     Text(
                        time != null ? DocSeraTime.format12hLocalized(context, time) : '',
                        style: AppTextStyles.getText3(context).copyWith(
                          fontSize: 10.sp,
                          color: Colors.black54,
                        ),
                     ),
                     if (isUser) ...[
                       SizedBox(width: 4.w),
                       if (status == 'sending')
                         SizedBox(
                           width: 10.w,
                           height: 10.w,
                           child: const CircularProgressIndicator(
                             strokeWidth: 1.5,
                             color: AppColors.main,
                           ),
                         )
                       else if (status == 'failed')
                         GestureDetector(
                           onTap: onRetryTap,
                           child: Icon(
                             Icons.error_outline,
                             color: Colors.redAccent,
                             size: 14.sp,
                           ),
                         )
                       else
                         Icon(
                           Icons.done_all,
                           color: isReadByDoctor ? AppColors.orange : Colors.black38,
                           size: 14.sp,
                         ),
                     ],
                   ],
                 ),
               ),
             ],
           ),
         );
       }
    }

    // Images
    if (images.isNotEmpty) {
      // ✅ Task 16: Determine expiry for this message.
      final imageExpiryDate = _expiryForMessage(messageId);
      final isExpiredImage = _isExpired(messageId);

      return Align(
        alignment: isUser ? Alignment.centerLeft : Alignment.centerRight,
        child: Column(
          crossAxisAlignment: isUser
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.end,
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
                      isUser ? accountHolderName : doctorName,
                      style: AppTextStyles.getText2(context).copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        fontSize: 12.sp,
                      ),
                    ),
                  ],
                ),
              ),
            // ✅ Task 16: Show expired placeholder instead of image grid.
            if (isExpiredImage)
              _buildExpiredPlaceholder(context, fileType: 'image')
            else
            ClipRRect(
              borderRadius: BorderRadius.circular(12.r),
              child: Container(
                constraints: BoxConstraints(maxWidth: 0.5.sw),
                child: GridView.count(
                  padding: EdgeInsets.zero,
                  crossAxisCount: images.length == 1 ? 1 : 2,
                  shrinkWrap: true,
                  crossAxisSpacing: 6.w,
                  mainAxisSpacing: 6.h,
                  physics: const ClampingScrollPhysics(),
                  clipBehavior: Clip.none,
                  children: List.generate(
                    images.length > 4 ? 4 : images.length,
                    (i) {
                      if (i == 3 && images.length > 4) {
                        return GestureDetector(
                          onTap: () async {
                            // Resolve all image URLs for full-screen viewer
                            final urls = await resolveImageUrls(images);
                            onOpenImages(
                              urls,
                              initialIndex: 3,
                              showAsGrid: true,
                              encrypted: images.any((a) => a['encrypted'] == true),
                            );
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
                      }
                      return GestureDetector(
                        onTap: () async {
                          final urls = await resolveImageUrls(images);
                          onOpenImages(
                            urls,
                            initialIndex: i,
                            encrypted: images.any((a) => a['encrypted'] == true),
                          );
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8.r),
                          // ✅ Each image is an independent cached widget
                          child: CachedChatImage(
                            attachment: images[i],
                            fit: BoxFit.cover,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            // ✅ Task 16: Expiry label below image grid.
            if (!isExpiredImage && imageExpiryDate != null)
              Align(
                alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: _buildExpiryLabel(context, imageExpiryDate),
              ),
            Padding(
              padding: EdgeInsets.only(top: 2.h),
              child: Align(
                alignment: isUser
                    ? Alignment.bottomRight
                    : Alignment.bottomLeft,
                child: Padding(
                  padding: EdgeInsets.only(top: 1.h),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        time != null
                            ? DocSeraTime.format12hLocalized(context, time)
                            : '',
                        style: AppTextStyles.getText3(context).copyWith(
                          fontSize: 10.sp,
                          color: Colors.black54,
                          height: 1.0,
                        ),
                      ),
                      if (isUser) ...[
                        SizedBox(width: 4.w),
                        if (status == 'sending')
                          SizedBox(
                            width: 10.w,
                            height: 10.w,
                            child: const CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: AppColors.main,
                            ),
                          )
                        else if (status == 'failed')
                          GestureDetector(
                            onTap: onRetryTap,
                            child: Icon(
                              Icons.error_outline,
                              color: Colors.redAccent,
                              size: 14.sp,
                            ),
                          )
                        else
                          Icon(
                            Icons.done_all,
                            color: isReadByDoctor ? AppColors.orange : Colors.black38,
                            size: 14.sp,
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
