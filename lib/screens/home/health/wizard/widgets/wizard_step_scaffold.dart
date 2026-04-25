import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';

/// Chrome for every wizard step.
///
/// Renders the title, optional subtitle, body, and footer (Skip + Next).
/// The Lottie header is rendered separately by the wizard page orchestrator,
/// so this scaffold does not own that visual element.
class WizardStepScaffold extends StatelessWidget {
  final String? lottieAssetName; // accepted but not rendered here (see class doc)
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
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 16.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTextStyles.getTitle1(context).copyWith(
                fontSize: 22.sp,
                color: AppColors.mainDark,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (subtitle != null) ...[
              SizedBox(height: 8.h),
              Text(
                subtitle!,
                style: AppTextStyles.getText2(context).copyWith(
                  color: AppColors.grayMain,
                ),
              ),
            ],
            SizedBox(height: 18.h),
            Expanded(child: body),
            if (onSkip != null)
              Padding(
                padding: EdgeInsets.only(top: 8.h),
                child: TextButton(
                  onPressed: onSkip,
                  child: Text(
                    skipLabel ?? t.healthProfile_skip_step,
                    style: TextStyle(
                      color: AppColors.main,
                      fontSize: 13.sp,
                    ),
                  ),
                ),
              ),
            if (onNext != null)
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: nextEnabled ? onNext : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.main,
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                  ),
                  child: Text(nextLabel ?? t.next),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
