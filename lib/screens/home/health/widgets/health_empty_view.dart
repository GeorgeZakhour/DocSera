import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';

class HealthEmptyView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  final String primaryButtonText;
  final VoidCallback onPrimaryPressed;

  final String? secondaryText;
  final VoidCallback? onSecondaryPressed;

  const HealthEmptyView({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.primaryButtonText,
    required this.onPrimaryPressed,
    this.secondaryText,
    this.onSecondaryPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Directionality.of(context) == TextDirection.rtl;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        /// ICON CIRCLE
        Center(
          child: Container(
            width: 120.w,
            height: 120.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.main.withOpacity(0.10),
              border: Border.all(
                color: AppColors.main.withOpacity(0.25),
                width: 1.2,
              ),
            ),
            child: Icon(
              icon,
              size: 48.sp,
              color: AppColors.mainDark,
            ),
          ),
        ),

        SizedBox(height: 22.h),

        /// TITLE
        Text(
          title,
          textAlign: TextAlign.center,
          style: AppTextStyles.getTitle1(context).copyWith(
            fontSize: 14.sp,
            color: AppColors.blackText,
          ),
        ),

        SizedBox(height: 4.h),

        /// SUBTITLE
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: AppTextStyles.getText2(context).copyWith(
            fontSize: 10.sp,
            color: AppColors.grayMain,
          ),
        ),

        SizedBox(height: 22.h),

        /// ADD BUTTON
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onPrimaryPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.main,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22.r),
              ),
              padding: EdgeInsets.symmetric(vertical: 11.h),
            ),
            child: Text(
              primaryButtonText,
              style: AppTextStyles.getText2(context).copyWith(
                fontSize: 12.sp,
                color: Colors.white,
              ),
            ),
          ),
        ),

        /// SECONDARY BUTTON (OPTIONAL)
        if (secondaryText != null) ...[
          SizedBox(height: 10.h),
          Center(
            child: TextButton(
              onPressed: onSecondaryPressed,
              child: Text(
                secondaryText!,
                style: AppTextStyles.getText3(context).copyWith(
                  fontSize: 10.sp,
                  color: AppColors.grayMain,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
