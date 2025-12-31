import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
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
import 'package:transparent_image/transparent_image.dart';

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
  final void Function(List<String> urls, {int initialIndex, bool showAsGrid})
  onOpenImages;

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
  });

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
      final time =
      intl.DateFormat('HH:mm', lang == 'ar' ? 'ar' : 'en').format(date);
      return lang == 'ar' ? 'أمس الساعة $time' : 'Yesterday at $time';
    } else {
      return intl.DateFormat('d MMM • HH:mm', lang == 'ar' ? 'ar' : 'en')
          .format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    final local = AppLocalizations.of(context)!;

    bool firstUserMessageFound = false;

    return ListView.builder(
      controller: scrollController,
      padding: EdgeInsets.only(
        left: 20.w,
        top: 12.h,
        right: 20.w,
        bottom: 65.h,
      ),
      itemCount: messages.length + pendingCount,
      itemBuilder: (context, index) {
        // Pending shimmer messages
        if (index >= messages.length) {
          return pendingBuilder(context, index - messages.length);
        }

        final msg = messages[index];
        final isUser = msg['is_user'] ?? false;
        final content = msg['text'] ?? '';
        final attachments =
            (msg['attachments'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final timestamp = DateTime.tryParse(msg['timestamp'] ?? '');
        final time = timestamp;

        final readByDoctorAt =
        DateTime.tryParse(msg['readByDoctorAt'] ?? '');
        final bool isReadByDoctor = isUser && (msg['read_by_doctor'] == true);

        final bool isLastRead =
            isReadByDoctor && (index == messages.length - 1);

        bool showSenderName = true;
        if (index > 0) {
          final prev = messages[index - 1];
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
        if (index > 0) {
          final previousTimestampString =
          (messages[index - 1])['timestamp'] as String?;
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
                          _getDayLabel(time, lang),
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
                              content: content,
                              attachments: attachments,
                              isUser: isUser,
                              avatar: avatar,
                              showReason: showReason,
                              time: time,
                              isArabic: isArabic,
                              showSenderName: showSenderName,
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
                                    '${local.read} • ${_formatReadTime(readByDoctorAt, lang)}',
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
  }) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 1, sigmaY: 1),
        child: IntrinsicWidth(
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
                      child: Text(
                        time != null
                            ? intl.DateFormat('HH:mm').format(
                          TimezoneUtils.toDamascus(time),
                        )
                            : '',
                        style: AppTextStyles.getText3(context).copyWith(
                          fontSize: 10.sp,
                          color:
                          isUser ? Colors.white70 : Colors.black54,
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

  Widget _buildAttachmentBubble({
    required BuildContext context,
    required List<Map<String, dynamic>> attachments,
    required bool isUser,
    required Widget avatar,
    required DateTime? time,
    required bool showSenderName,
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
            GestureDetector(
              onTap: () async {
                // Old style: file_url / fileUrl
                String? url =
                (pdf['file_url'] ?? pdf['fileUrl'])?.toString();

                // Fallback: bucket + paths
                if (url == null || url.trim().isEmpty) {
                  final bucket =
                  (pdf['bucket'] ?? 'chat.attachments').toString();
                  final paths = (pdf['paths'] as List?) ?? [];
                  if (paths.isEmpty) return;
                  // This widget doesn't know how to sign URLs, so assume direct URL
                  url = paths.first.toString();
                }

                if (url.trim().isEmpty) return;

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
                  uploadedAt: DateTime.now(),
                  uploadedById: '',
                  cameFromConversation: true,
                  conversationDoctorName: doctorName,
                );

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DocumentPreviewPage(
                      document: userDoc,
                      cameFromConversation: true,
                      doctorName: doctorName,
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
            Padding(
              padding: EdgeInsets.only(top: 2.h),
              child: Align(
                alignment: isUser
                    ? Alignment.bottomRight
                    : Alignment.bottomLeft,
                child: Padding(
                  padding: EdgeInsets.only(top: 1.h),
                  child: Text(
                    time != null
                        ? intl.DateFormat('HH:mm').format(
                      TimezoneUtils.toDamascus(time),
                    )
                        : '',
                    style: AppTextStyles.getText3(context).copyWith(
                      fontSize: 10.sp,
                      color: Colors.black54,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Images
    if (images.isNotEmpty) {
      return Align(
        alignment: isUser ? Alignment.centerLeft : Alignment.centerRight,
        child: FutureBuilder<List<String>>(
          future: resolveImageUrls(images),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Padding(
                padding: EdgeInsets.symmetric(vertical: 8.h),
                child: SizedBox(
                  width: 120.w,
                  height: 120.w,
                  child: const Center(
                    child: FullPageLoader(),
                  ),
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const SizedBox.shrink();
            }

            final validImages = snapshot.data!;

            return Column(
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
                ClipRRect(
                  borderRadius: BorderRadius.circular(12.r),
                  child: GestureDetector(
                    onTap: () =>
                        onOpenImages(validImages, initialIndex: 0),
                    child: Container(
                      constraints: BoxConstraints(maxWidth: 0.5.sw),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return GridView.count(
                            padding: EdgeInsets.zero,
                            crossAxisCount:
                            validImages.length == 1 ? 1 : 2,
                            shrinkWrap: true,
                            crossAxisSpacing: 6.w,
                            mainAxisSpacing: 6.h,
                            physics: const ClampingScrollPhysics(),
                            clipBehavior: Clip.none,
                            children: List.generate(
                              validImages.length > 4
                                  ? 4
                                  : validImages.length,
                                  (i) {
                                final imageUrl = validImages[i];
                                if (i == 3 &&
                                    validImages.length > 4) {
                                  return GestureDetector(
                                    onTap: () => onOpenImages(
                                      validImages,
                                      initialIndex: 3,
                                      showAsGrid: true,
                                    ),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: AppColors.main
                                            .withOpacity(0.1),
                                        borderRadius:
                                        BorderRadius.circular(8.r),
                                      ),
                                      child: Center(
                                        child: CircleAvatar(
                                          radius: 16.r,
                                          backgroundColor: Colors.white
                                              .withOpacity(0.85),
                                          child: Text(
                                            '+${validImages.length - 3}',
                                            style: AppTextStyles
                                                .getText3(context)
                                                .copyWith(
                                              fontSize: 10.sp,
                                              color: AppColors.main,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                } else {
                                  return GestureDetector(
                                    onTap: () => onOpenImages(
                                      validImages,
                                      initialIndex: i,
                                    ),
                                    child: ClipRRect(
                                      borderRadius:
                                      BorderRadius.circular(8.r),
                                      child: FadeInImage(
                                        placeholder:
                                        MemoryImage(kTransparentImage),
                                        image: CachedNetworkImageProvider(
                                            imageUrl),
                                        fadeInDuration: const Duration(
                                            milliseconds: 100),
                                        fit: BoxFit.cover,
                                        placeholderFit: BoxFit.cover,
                                        imageErrorBuilder:
                                            (_, __, ___) =>
                                        const Icon(Icons.error),
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(top: 2.h),
                  child: Align(
                    alignment: isUser
                        ? Alignment.bottomRight
                        : Alignment.bottomLeft,
                    child: Padding(
                      padding: EdgeInsets.only(top: 1.h),
                      child: Text(
                        time != null
                            ? intl.DateFormat('HH:mm').format(
                          TimezoneUtils.toDamascus(time),
                        )
                            : '',
                        style: AppTextStyles.getText3(context).copyWith(
                          fontSize: 10.sp,
                          color: Colors.black54,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
