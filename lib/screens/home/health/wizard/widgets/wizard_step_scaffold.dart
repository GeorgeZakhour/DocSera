import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';

/// Chrome for every wizard step.
///
/// Title + subtitle live above a soft-bordered card holding the body. Skip
/// is a low-emphasis ghost link; Next is a primary ElevatedButton matching
/// the rest of the Docsera app's button language.
class WizardStepScaffold extends StatelessWidget {
  final String? lottieAssetName;
  final String title;
  final String? subtitle;
  final Widget body;
  final VoidCallback? onSkip;
  final VoidCallback? onNext;
  final bool nextEnabled;
  final String? nextLabel;
  final String? skipLabel;

  const WizardStepScaffold({
    super.key,
    this.lottieAssetName,
    required this.title,
    this.subtitle,
    required this.body,
    this.onSkip,
    this.onNext,
    this.nextEnabled = true,
    this.nextLabel,
    this.skipLabel,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 16.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTextStyles.getTitle3(context).copyWith(
                color: AppColors.mainDark,
                height: 1.25,
              ),
            ),
            if (subtitle != null) ...[
              SizedBox(height: 6.h),
              Text(
                subtitle!,
                style: AppTextStyles.getText2(context).copyWith(
                  color: AppColors.grayMain,
                  height: 1.4,
                ),
              ),
            ],
            SizedBox(height: 20.h),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(18.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(
                    color: AppColors.main.withValues(alpha: 0.10),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.mainDark.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: body,
              ),
            ),
            SizedBox(height: 16.h),
            if (onSkip != null)
              Center(
                child: TextButton(
                  onPressed: onSkip,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 6.h,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    skipLabel ?? t.healthProfile_skip_step,
                    style: AppTextStyles.getText2(context).copyWith(
                      color: AppColors.grayMain,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.underline,
                      decorationColor:
                          AppColors.grayMain.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),
            if (onNext != null) ...[
              SizedBox(height: 8.h),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: nextEnabled ? onNext : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        nextEnabled ? AppColors.main : Colors.grey,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  child: Text(
                    nextLabel ?? t.next,
                    style: AppTextStyles.getText2(context).copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
