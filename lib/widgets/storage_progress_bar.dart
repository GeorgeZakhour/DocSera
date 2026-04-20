import 'package:docsera/Business_Logic/Storage/storage_quota_cubit.dart';
import 'package:docsera/Business_Logic/Storage/storage_quota_state.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// A reusable storage usage widget with two display modes.
///
/// - [compact] = false (Documents page): full card with title, usage text,
///   progress bar, and subtitle showing percentage + file count.
/// - [compact] = true (Account page): single-row with label, usage text,
///   and inline progress bar.
///
/// Tapping either mode triggers [onTap] if provided.
/// Returns [SizedBox.shrink] when the cubit state is not [StorageQuotaLoaded].
class StorageProgressBar extends StatelessWidget {
  final bool compact;
  final VoidCallback? onTap;

  const StorageProgressBar({
    super.key,
    this.compact = false,
    this.onTap,
  });

  /// Returns the progress-bar colour based on usage percentage.
  Color _barColor(double pct) {
    if (pct >= 90) return Colors.red.shade600;
    if (pct >= 70) return Colors.orange.shade600;
    return Colors.green.shade600;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StorageQuotaCubit, StorageQuotaState>(
      builder: (context, state) {
        if (state is! StorageQuotaLoaded) return const SizedBox.shrink();

        final quota = state.quota;
        final pct = quota.usedPercentage.clamp(0.0, 100.0);
        final barColor = _barColor(pct);
        final progress = pct / 100.0;

        return compact
            ? _buildCompact(
                context, quota.usedFormatted, quota.maxFormatted,
                progress, barColor)
            : _buildFull(
                context, quota.usedFormatted, quota.maxFormatted,
                progress, barColor, pct, quota.fileCount);
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Full mode (Documents page)
  // ---------------------------------------------------------------------------

  Widget _buildFull(
    BuildContext context,
    String used,
    String max,
    double progress,
    Color barColor,
    double pct,
    int fileCount,
  ) {
    final l10n = AppLocalizations.of(context);
    final title = l10n?.myStorageTitle ?? 'My Storage';
    final usedWord = l10n?.storageUsedLabel ?? 'used';
    final filesWord = l10n?.storageFilesLabel ?? 'files';
    final pctLabel = pct.toStringAsFixed(0);
    final subtitleText = '$pctLabel% $usedWord · $fileCount $filesWord';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: barColor.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Title row ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: AppTextStyles.getTitle1(context)
                      .copyWith(color: AppColors.main),
                ),
                Text(
                  '$used / $max',
                  style: AppTextStyles.getText2(context)
                      .copyWith(color: AppColors.textSubColor),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            // --- Progress bar ---
            ClipRRect(
              borderRadius: BorderRadius.circular(4.r),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6.h,
                backgroundColor: barColor.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
            SizedBox(height: 6.h),
            // --- Subtitle ---
            Text(
              subtitleText,
              style: AppTextStyles.getText3(context)
                  .copyWith(color: AppColors.textSubColor),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Compact mode (Account page)
  // ---------------------------------------------------------------------------

  Widget _buildCompact(
    BuildContext context,
    String used,
    String max,
    double progress,
    Color barColor,
  ) {
    final l10n = AppLocalizations.of(context);
    final label = l10n?.storageTitle ?? 'Storage';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: barColor.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(Icons.storage_rounded, size: 16.sp, color: AppColors.main),
            SizedBox(width: 8.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        label,
                        style: AppTextStyles.getText2(context)
                            .copyWith(color: AppColors.blackText),
                      ),
                      Text(
                        '$used / $max',
                        style: AppTextStyles.getText3(context)
                            .copyWith(color: AppColors.textSubColor),
                      ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4.r),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 4.h,
                      backgroundColor: barColor.withValues(alpha: 0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(barColor),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 8.w),
            Icon(Icons.chevron_right, size: 16.sp, color: AppColors.grayMain),
          ],
        ),
      ),
    );
  }
}
