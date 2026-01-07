import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';

class HealthEmptyView extends StatelessWidget {
  final IconData? icon;
  final String? imagePath;
  final String title;
  final String subtitle;

  final String primaryButtonText;
  final VoidCallback onPrimaryPressed;

  const HealthEmptyView({
    super.key,
    this.icon,
    this.imagePath,
    required this.title,
    required this.subtitle,
    required this.primaryButtonText,
    required this.onPrimaryPressed,
  }) : assert(icon != null || imagePath != null, "Either icon or imagePath must be provided");

  @override
  Widget build(BuildContext context) {
    // Determine the icon/image widget
    Widget visualWidget;
    if (imagePath != null) {
      visualWidget = Image.asset(
        imagePath!,
        width: 140.w,
        height: 140.w,
        fit: BoxFit.contain,
      );
    } else {
      visualWidget = Container(
        width: 100.w,
        height: 100.w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.main.withOpacity(0.08),
        ),
        child: Center(
          child: Icon(
            icon,
            size: 40.sp,
            color: AppColors.main,
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          /// VISUAL (ICON or IMAGE)
          Center(child: visualWidget),

          SizedBox(height: 32.h),

          /// TITLE
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyles.getTitle2(context).copyWith(
              color: AppColors.mainDark,
              height: 1.3,
            ),
          ),

          SizedBox(height: 12.h),

          /// SUBTITLE
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: AppTextStyles.getText2(context).copyWith(
              color: AppColors.grayMain,
              height: 1.5,
            ),
          ),

          SizedBox(height: 40.h),

          /// ADD BUTTON
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onPrimaryPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.main,
                foregroundColor: Colors.white,
                elevation: 0,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r),
                ),
                padding: EdgeInsets.symmetric(vertical: 16.h),
              ),
              child: Text(
                primaryButtonText,
                style: AppTextStyles.getTitle2(context).copyWith(
                  fontSize: 14.sp,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
