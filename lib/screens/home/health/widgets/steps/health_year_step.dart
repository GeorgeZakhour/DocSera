import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/screens/home/health/widgets/health_ghost_button.dart';

/// ------------------------------------------------------------
/// GENERIC YEAR SELECTION STEP
/// ------------------------------------------------------------
class HealthYearStep extends StatelessWidget {
  final String title;
  final String? subtitle;

  final List<int> years;
  final int? selectedYear;

  final String nextText;
  final String skipText;

  final bool skippable;

  final void Function(int?) onChanged;
  final VoidCallback onNext;
  final VoidCallback? onSkip;

  const HealthYearStep({
    super.key,
    required this.title,
    this.subtitle,
    required this.years,
    required this.selectedYear,
    required this.onChanged,
    required this.nextText,
    required this.skipText,
    required this.onNext,
    this.onSkip,
    this.skippable = true,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Directionality.of(context) == TextDirection.rtl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 10.h),

        /// TITLE
        Text(
          title,
          style: AppTextStyles.getTitle1(context).copyWith(
            fontSize: 12.sp,
            color: AppColors.mainDark,
          ),
        ),

        if (subtitle != null) ...[
          SizedBox(height: 3.h),
          Text(
            subtitle!,
            style: AppTextStyles.getText3(context).copyWith(
              fontSize: 11.sp,
              color: AppColors.grayMain,
            ),
          ),
        ],

        SizedBox(height: 14.h),

        /// YEAR DROPDOWN — identical to old allergy page
        DropdownButtonFormField<int>(
          value: selectedYear,
          decoration: InputDecoration(
            labelText: subtitle, // Same behavior as old code
            labelStyle: AppTextStyles.getText3(context).copyWith(
              color: selectedYear == null ? Colors.grey : AppColors.main,
              fontSize: 12.sp,
            ),
            floatingLabelBehavior: FloatingLabelBehavior.auto,
            contentPadding:
            EdgeInsets.symmetric(vertical: 12.h, horizontal: 14.w),
            filled: true,
            fillColor: Colors.white,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(25.r),
              borderSide: BorderSide(color: Colors.grey.shade400),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(25.r),
              borderSide: BorderSide(color: AppColors.main, width: 2),
            ),
          ),
          dropdownColor: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(15.r),
          isExpanded: true,
          icon: Icon(
            Icons.arrow_drop_down,
            color: AppColors.main,
            size: 22.sp,
          ),
          items: years
              .map(
                (year) => DropdownMenuItem<int>(
              value: year,
              child: Text(
                "$year",
                style: AppTextStyles.getTitle1(context).copyWith(
                  fontSize: 13.sp,
                  color: AppColors.blackText,
                ),
              ),
            ),
          )
              .toList(),
          onChanged: onChanged,
        ),

        const Spacer(),

        /// SKIP BUTTON — identical behavior
        if (skippable)
          Padding(
            padding: EdgeInsets.only(bottom: 6.h),
            child: HealthGhostButton(
              text: skipText,
              onTap: onSkip ?? () {},
            ),
          ),

        /// NEXT BUTTON
        GestureDetector(
          onTap: selectedYear == null && !skippable ? null : onNext,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 12.h),
            decoration: BoxDecoration(
              color: selectedYear != null || skippable
                  ? AppColors.main
                  : AppColors.main.withOpacity(0.35),
              borderRadius: BorderRadius.circular(24.r),
            ),
            child: Center(
              child: Text(
                nextText,
                style: AppTextStyles.getText2(context).copyWith(
                  fontSize: 11.sp,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),

        SizedBox(height: 15.h),
      ],
    );
  }
}
