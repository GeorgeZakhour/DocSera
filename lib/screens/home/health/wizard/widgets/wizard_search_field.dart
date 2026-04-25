import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/app/const.dart';

/// Refined search input used at the top of multi-select wizard steps.
/// Soft tinted background, search icon prefix, no hard border.
class WizardSearchField extends StatelessWidget {
  final ValueChanged<String> onChanged;
  final String hint;

  const WizardSearchField({
    super.key,
    required this.onChanged,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.main.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: AppColors.main.withValues(alpha: 0.12),
        ),
      ),
      padding: EdgeInsetsDirectional.only(start: 12.w, end: 12.w),
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            color: AppColors.grayMain,
            size: 18.sp,
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: TextField(
              onChanged: onChanged,
              style: TextStyle(
                fontSize: 13.5.sp,
                color: AppColors.mainDark,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(
                  color: AppColors.grayMain,
                  fontSize: 13.sp,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 12.h),
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
