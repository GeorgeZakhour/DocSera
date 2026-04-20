import 'package:docsera/Business_Logic/Storage/storage_quota_cubit.dart';
import 'package:docsera/Business_Logic/Storage/storage_quota_state.dart';
import 'package:docsera/services/supabase/storage_quota_service.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class StorageProgressBar extends StatelessWidget {
  final bool compact;
  final VoidCallback? onTap;

  const StorageProgressBar({
    super.key,
    this.compact = false,
    this.onTap,
  });

  /// Teal at normal usage, warm amber approaching limit, soft red when full.
  Color _barColor(double pct) {
    if (pct >= 90) return const Color(0xFFE05252);
    if (pct >= 70) return const Color(0xFFE8A84C);
    return AppColors.main;
  }

  Color _barBgColor(double pct) {
    if (pct >= 90) return const Color(0xFFE05252).withValues(alpha: 0.12);
    if (pct >= 70) return const Color(0xFFE8A84C).withValues(alpha: 0.12);
    return AppColors.main.withValues(alpha: 0.12);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StorageQuotaCubit, StorageQuotaState>(
      builder: (context, state) {
        if (state is! StorageQuotaLoaded) return const SizedBox.shrink();

        final quota = state.quota;
        final pct = quota.usedPercentage.clamp(0.0, 100.0);
        final barColor = _barColor(pct);
        final bgColor = _barBgColor(pct);
        final progress = pct / 100.0;

        return compact
            ? _buildCompact(context, quota, progress, barColor, bgColor, pct)
            : _buildFull(context, quota, progress, barColor, bgColor, pct);
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Full mode (Documents page)
  // ---------------------------------------------------------------------------

  Widget _buildFull(
    BuildContext context,
    StorageQuotaResult quota,
    double progress,
    Color barColor,
    Color bgColor,
    double pct,
  ) {
    final l10n = AppLocalizations.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: AppColors.main.withValues(alpha:0.05),
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: Row(
          children: [
            // Cloud icon
            Container(
              width: 40.w,
              height: 40.w,
              decoration: BoxDecoration(
                color: barColor.withValues(alpha:0.12),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(
                pct >= 90
                    ? Icons.cloud_off_rounded
                    : Icons.cloud_done_rounded,
                color: barColor,
                size: 20.sp,
              ),
            ),
            SizedBox(width: 12.w),

            // Text + bar
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n?.myStorageTitle ?? 'My Storage',
                        style: AppTextStyles.getText1(context).copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.blackText,
                        ),
                      ),
                      Text(
                        '${quota.usedFormatted} / ${quota.maxFormatted}',
                        style: AppTextStyles.getText3(context).copyWith(
                          color: AppColors.grayMain,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),

                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6.r),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: progress),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) => LinearProgressIndicator(
                        value: value,
                        minHeight: 8.h,
                        backgroundColor: bgColor,
                        valueColor: AlwaysStoppedAnimation<Color>(barColor),
                      ),
                    ),
                  ),
                  SizedBox(height: 6.h),

                  // Subtitle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${quota.fileCount} ${l10n?.storageFilesLabel ?? 'files'}',
                        style: AppTextStyles.getText3(context).copyWith(
                          color: AppColors.grayMain,
                          fontSize: 10.sp,
                        ),
                      ),
                      Text(
                        '${pct.toStringAsFixed(0)}% ${l10n?.storageUsedLabel ?? 'used'}',
                        style: AppTextStyles.getText3(context).copyWith(
                          color: barColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 10.sp,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
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
    StorageQuotaResult quota,
    double progress,
    Color barColor,
    Color bgColor,
    double pct,
  ) {
    final l10n = AppLocalizations.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: AppColors.main.withValues(alpha:0.05),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 32.w,
              height: 32.w,
              decoration: BoxDecoration(
                color: barColor.withValues(alpha:0.12),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Icon(
                Icons.cloud_done_rounded,
                color: barColor,
                size: 16.sp,
              ),
            ),
            SizedBox(width: 10.w),

            // Text + bar
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n?.storageTitle ?? 'Storage',
                        style: AppTextStyles.getText2(context).copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.blackText,
                        ),
                      ),
                      Text(
                        '${quota.usedFormatted} / ${quota.maxFormatted}',
                        style: AppTextStyles.getText3(context).copyWith(
                          color: AppColors.grayMain,
                          fontSize: 10.sp,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6.h),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4.r),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: progress),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) => LinearProgressIndicator(
                        value: value,
                        minHeight: 5.h,
                        backgroundColor: bgColor,
                        valueColor: AlwaysStoppedAnimation<Color>(barColor),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 8.w),

            // Chevron
            Icon(
              Icons.chevron_right_rounded,
              size: 18.sp,
              color: AppColors.grayMain,
            ),
          ],
        ),
      ),
    );
  }
}
