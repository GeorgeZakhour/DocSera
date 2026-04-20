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

  /// Shows an informational dialog when storage reaches 70 %.
  /// Dismissing calls [StorageQuotaCubit.markWarningShown(70)].
  static Future<void> show70Warning(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<StorageQuotaCubit>();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.r)),
          title: Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  color: Colors.orange.shade600, size: 22.sp),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  l10n?.storageWarning70Title ?? 'Storage Getting Full',
                  style: AppTextStyles.getTitle2(context)
                      .copyWith(color: AppColors.blackText),
                ),
              ),
            ],
          ),
          content: Text(
            l10n?.storageWarning70Body ??
                'You have used 70% of your available storage. '
                    'Consider removing old or unused files to keep things tidy.',
            style: AppTextStyles.getText1(context)
                .copyWith(color: AppColors.textSubColor),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                cubit.markWarningShown(70);
              },
              child: Text(
                l10n?.okGotIt ?? 'OK, Got It',
                style: AppTextStyles.getText1(context)
                    .copyWith(color: AppColors.main),
              ),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 90 % warning
  // ---------------------------------------------------------------------------

  /// Shows an urgent dialog when storage reaches 90 %.
  /// [onManageStorage] is called when the user taps "Manage Storage".
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
        return AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.r)),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: Colors.red.shade600, size: 22.sp),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  l10n?.storageWarning90Title ?? 'Storage Almost Full',
                  style: AppTextStyles.getTitle2(context)
                      .copyWith(color: Colors.red.shade700),
                ),
              ),
            ],
          ),
          content: Text(
            l10n?.storageWarning90Body ??
                'You have used 90% of your storage. '
                    'Upload will be blocked when you reach 100%. '
                    'Delete some documents to free up space.',
            style: AppTextStyles.getText1(context)
                .copyWith(color: AppColors.textSubColor),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                cubit.markWarningShown(90);
              },
              child: Text(
                'Dismiss',
                style: AppTextStyles.getText1(context)
                    .copyWith(color: AppColors.textSubColor),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.main,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r)),
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                cubit.markWarningShown(90);
                onManageStorage?.call();
              },
              child: Text(
                l10n?.storageManage ?? 'Manage Storage',
                style: AppTextStyles.getText1(context)
                    .copyWith(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Auto-check helper
  // ---------------------------------------------------------------------------

  /// Checks the current usage thresholds and shows the appropriate dialog.
  ///
  /// - Shows the 90 % dialog first if [usedPercentage] >= 90 and
  ///   [warning90Shown] is false.
  /// - Falls back to the 70 % dialog if [usedPercentage] >= 70 and
  ///   [warning70Shown] is false.
  static Future<void> checkAndShowWarning(
    BuildContext context, {
    required double usedPercentage,
    required bool warning70Shown,
    required bool warning90Shown,
    VoidCallback? onManageStorage,
  }) async {
    if (usedPercentage >= 90 && !warning90Shown) {
      await show90Warning(context, onManageStorage: onManageStorage);
    } else if (usedPercentage >= 70 && !warning70Shown) {
      await show70Warning(context);
    }
  }
}
