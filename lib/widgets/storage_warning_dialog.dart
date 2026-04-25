import 'package:docsera/Business_Logic/Storage/storage_quota_cubit.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Utility class for showing storage-warning dialogs at 70 % and 90 % usage.
class StorageWarningDialog {
  StorageWarningDialog._();

  // ---------------------------------------------------------------------------
  // 70 % warning
  // ---------------------------------------------------------------------------

  static Future<void> show70Warning(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<StorageQuotaCubit>();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 28.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon
                Container(
                  width: 56.w,
                  height: 56.w,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.cloud_queue_rounded,
                    color: const Color(0xFFF59E0B),
                    size: 28.sp,
                  ),
                ),
                SizedBox(height: 16.h),

                // Title
                Text(
                  l10n?.storageWarning70Title ?? 'Storage Getting Full',
                  style: AppTextStyles.getTitle2(context).copyWith(
                    color: AppColors.blackText,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 10.h),

                // Body
                Text(
                  l10n?.storageWarning70Body ??
                      'You have used 70% of your available storage. '
                          'Consider removing old or unused files to keep things tidy.',
                  style: AppTextStyles.getText2(context).copyWith(
                    color: AppColors.grayMain,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24.h),

                // Button
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      cubit.markWarningShown(70);
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                    ),
                    child: Text(
                      l10n?.okGotIt ?? 'OK, Got It',
                      style: AppTextStyles.getText1(context).copyWith(
                        color: AppColors.main,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 90 % warning
  // ---------------------------------------------------------------------------

  static Future<void> show90Warning(
    BuildContext context, {
    VoidCallback? onManageStorage,
  }) async {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<StorageQuotaCubit>();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 28.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon
                Container(
                  width: 56.w,
                  height: 56.w,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.cloud_off_rounded,
                    color: const Color(0xFFEF4444),
                    size: 28.sp,
                  ),
                ),
                SizedBox(height: 16.h),

                // Title
                Text(
                  l10n?.storageWarning90Title ?? 'Storage Almost Full',
                  style: AppTextStyles.getTitle2(context).copyWith(
                    color: const Color(0xFFEF4444),
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 10.h),

                // Body
                Text(
                  l10n?.storageWarning90Body ??
                      'You have used 90% of your storage. '
                          'Upload will be blocked when you reach 100%. '
                          'Delete some documents to free up space.',
                  style: AppTextStyles.getText2(context).copyWith(
                    color: AppColors.grayMain,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24.h),

                // Manage Storage button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      cubit.markWarningShown(90);
                      onManageStorage?.call();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.main,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    child: Text(
                      l10n?.storageManage ?? 'Manage Storage',
                      style: AppTextStyles.getText1(context).copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 8.h),

                // Dismiss
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    cubit.markWarningShown(90);
                  },
                  child: Text(
                    l10n?.storageDismiss ?? 'Dismiss',
                    style: AppTextStyles.getText2(context).copyWith(
                      color: AppColors.grayMain,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Auto-check helper
  // ---------------------------------------------------------------------------

  static Future<void> checkAndShowWarning(
    BuildContext context, {
    required double usedPercentage,
    required bool warning70Shown,
    required bool warning90Shown,
    VoidCallback? onManageStorage,
  }) async {
    if (usedPercentage >= 90 && !warning90Shown) {
      await show90Warning(context, onManageStorage: onManageStorage);
    } else if (usedPercentage >= 70 && usedPercentage < 90 && !warning70Shown) {
      await show70Warning(context);
    }
  }
}
