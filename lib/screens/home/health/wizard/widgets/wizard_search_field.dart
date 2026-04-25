import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';

/// Refined search input used at the top of multi-select wizard steps.
/// Matches Docsera's text-field language: pill border, AppTextStyles font.
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
    return TextField(
      onChanged: onChanged,
      style: AppTextStyles.getText2(context).copyWith(
        color: AppColors.mainDark,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.getText2(context).copyWith(
          color: Colors.grey,
        ),
        prefixIcon: Icon(
          Icons.search_rounded,
          color: AppColors.grayMain,
          size: 18.sp,
        ),
        prefixIconConstraints: BoxConstraints(
          minWidth: 38.w,
          minHeight: 18.sp,
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 12.w,
          vertical: 10.h,
        ),
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25.r),
          borderSide: const BorderSide(color: Colors.grey),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25.r),
          borderSide: const BorderSide(color: Colors.grey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25.r),
          borderSide: const BorderSide(color: AppColors.main, width: 2),
        ),
      ),
    );
  }
}
