import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';

class HealthNoItemsView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  final String changeDecisionText;
  final VoidCallback onChangeDecision;

  final String addButtonText;
  final VoidCallback onAddPressed;

  const HealthNoItemsView({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.changeDecisionText,
    required this.onChangeDecision,
    required this.addButtonText,
    required this.onAddPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Directionality.of(context) == TextDirection.rtl;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        /// MAIN ICON
        Center(
          child: Icon(
            icon,
            size: 58.sp,
            color: AppColors.main,
          ),
        ),

        SizedBox(height: 18.h),

        /// TITLE
        Text(
          title,
          textAlign: isArabic ? TextAlign.right : TextAlign.left,
          style: AppTextStyles.getTitle1(context).copyWith(
            fontSize: 14.sp,
            color: AppColors.blackText,
          ),
        ),

        SizedBox(height: 4.h),

        /// SUBTITLE
        Text(
          subtitle,
          textAlign: isArabic ? TextAlign.right : TextAlign.left,
          style: AppTextStyles.getText2(context).copyWith(
            fontSize: 10.sp,
            color: AppColors.grayMain,
          ),
        ),

        SizedBox(height: 18.h),

        /// Change decision (Text button)
        TextButton(
          onPressed: onChangeDecision,
          child: Text(
            changeDecisionText,
            style: AppTextStyles.getText3(context).copyWith(
              fontSize: 10.sp,
              color: AppColors.mainDark,
              decoration: TextDecoration.underline,
            ),
          ),
        ),

        SizedBox(height: 12.h),

        /// Main ADD BUTTON
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onAddPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.main,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: EdgeInsets.symmetric(vertical: 11.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22.r),
              ),
            ),
            child: Text(
              addButtonText,
              style: AppTextStyles.getText2(context).copyWith(
                fontSize: 12.sp,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
