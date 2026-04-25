import 'dart:ui';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/utils/time_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Banner displayed at the top of a chat conversation when one or more media
/// attachments are approaching their expiry date.
///
/// - Orange-tinted glass when expiry is within 30 days.
/// - Red-tinted glass when expiry is within 7 days.
/// - Tapping the banner triggers [onTap] (intended to scroll to the first
///   expiring message).
/// - The dismiss button calls [onDismiss].
class ChatExpiryBanner extends StatelessWidget {
  /// The earliest expiry date among all expiring files in this conversation.
  final DateTime earliestExpiry;

  /// Number of files that are expiring.
  final int fileCount;

  /// Called when the user taps the banner body (e.g. scroll to first expiring message).
  final VoidCallback? onTap;

  /// Called when the user dismisses the banner.
  final VoidCallback? onDismiss;

  const ChatExpiryBanner({
    super.key,
    required this.earliestExpiry,
    required this.fileCount,
    this.onTap,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    final now = DocSeraTime.nowSyria();
    final diff = earliestExpiry.difference(now);
    final daysLeft = diff.inDays;

    // Choose colour based on urgency.
    final bool isUrgent = daysLeft <= 7;
    final Color tint = isUrgent
        ? Colors.red.shade700
        : Colors.orange.shade800;

    final String expiryLabel = DocSeraTime.formatBusinessDate(context, earliestExpiry);

    return GestureDetector(
      onTap: onTap,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.75),
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 0.5,
                ),
              ),
            ),
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18.sp),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    '${local.filesExpiringSoon} $expiryLabel. ${local.saveImportantFiles}',
                    style: AppTextStyles.getText3(context).copyWith(
                      color: Colors.white,
                      fontSize: 11.sp,
                    ),
                  ),
                ),
                if (onDismiss != null) ...[
                  SizedBox(width: 4.w),
                  GestureDetector(
                    onTap: onDismiss,
                    child: Icon(Icons.close, color: Colors.white70, size: 16.sp),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
