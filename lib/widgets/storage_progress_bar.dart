import 'dart:ui';
import 'package:docsera/Business_Logic/Storage/storage_quota_cubit.dart';
import 'package:docsera/Business_Logic/Storage/storage_quota_state.dart';
import 'package:docsera/services/supabase/storage_quota_service.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Collapsed glass pill that expands into a full storage card.
///
/// The parent must provide expand/collapse callback so the Positioned
/// constraints can change (pill = one corner, card = full width).
class StorageProgressBar extends StatelessWidget {
  final bool expanded;
  final VoidCallback onToggle;

  const StorageProgressBar({
    super.key,
    required this.expanded,
    required this.onToggle,
  });

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
        final progress = (pct / 100.0).clamp(0.0, 1.0);

        return AnimatedCrossFade(
          duration: const Duration(milliseconds: 250),
          sizeCurve: Curves.easeOutCubic,
          firstCurve: Curves.easeOut,
          secondCurve: Curves.easeOut,
          crossFadeState: expanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: _buildCollapsedPill(context, quota, barColor, pct),
          secondChild: _buildExpandedCard(
              context, quota, barColor, bgColor, progress, pct),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Collapsed pill
  // ---------------------------------------------------------------------------
  Widget _buildCollapsedPill(
    BuildContext context,
    StorageQuotaResult quota,
    Color barColor,
    double pct,
  ) {
    return GestureDetector(
      onTap: onToggle,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20.r),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(
                color: barColor.withValues(alpha: 0.25),
                width: 0.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  pct >= 90
                      ? Icons.cloud_off_rounded
                      : Icons.cloud_done_rounded,
                  color: barColor,
                  size: 14.sp,
                ),
                SizedBox(width: 5.w),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    '${pct.toStringAsFixed(0)}%',
                    style: AppTextStyles.getText3(context).copyWith(
                      color: barColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 10.sp,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Expanded card
  // ---------------------------------------------------------------------------
  Widget _buildExpandedCard(
    BuildContext context,
    StorageQuotaResult quota,
    Color barColor,
    Color bgColor,
    double progress,
    double pct,
  ) {
    final l10n = AppLocalizations.of(context);

    return GestureDetector(
      onTap: onToggle,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14.r),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(
                color: barColor.withValues(alpha: 0.15),
                width: 0.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header row
                Row(
                  children: [
                    Container(
                      width: 32.w,
                      height: 32.w,
                      decoration: BoxDecoration(
                        color: barColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Icon(
                        pct >= 90
                            ? Icons.cloud_off_rounded
                            : Icons.cloud_done_rounded,
                        color: barColor,
                        size: 16.sp,
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Text(
                        l10n?.myStorageTitle ?? 'My Storage',
                        style: AppTextStyles.getText1(context).copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.blackText,
                        ),
                      ),
                    ),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        '${quota.usedFormatted} / ${quota.maxFormatted}',
                        style: AppTextStyles.getText3(context).copyWith(
                          color: AppColors.grayMain,
                          fontSize: 10.sp,
                        ),
                      ),
                    ),
                    SizedBox(width: 4.w),
                    Icon(
                      Icons.keyboard_arrow_up_rounded,
                      color: AppColors.grayMain,
                      size: 16.sp,
                    ),
                  ],
                ),
                SizedBox(height: 10.h),

                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(5.r),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: progress),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) => LinearProgressIndicator(
                      value: value,
                      minHeight: 6.h,
                      backgroundColor: bgColor,
                      valueColor: AlwaysStoppedAnimation<Color>(barColor),
                    ),
                  ),
                ),
                SizedBox(height: 6.h),

                // Footer
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        '${quota.fileCount} ${l10n?.storageFilesLabel ?? 'files'}',
                        style: AppTextStyles.getText3(context).copyWith(
                          color: AppColors.grayMain,
                          fontSize: 9.sp,
                        ),
                      ),
                    ),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        '${pct.toStringAsFixed(0)}% ${l10n?.storageUsedLabel ?? 'used'}',
                        style: AppTextStyles.getText3(context).copyWith(
                          color: barColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 9.sp,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
