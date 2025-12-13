import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/screens/home/health/widgets/health_primary_button.dart';
import 'package:docsera/screens/home/health/widgets/health_ghost_button.dart';

/// ------------------------------------------------------------
/// GENERIC OPTIONS STEP (Single Choice)
/// For: severity, type, category, etc.
/// ------------------------------------------------------------
class HealthOptionsStep<T> extends StatelessWidget {
  final String title;
  final String? subtitle;

  /// key → localized string value
  final Map<T, String> options;

  final T? selected;

  final bool skippable;
  final String? skipText;

  final String nextText;

  final void Function(T value) onSelect;

  final VoidCallback onNext;
  final VoidCallback? onSkip;

  const HealthOptionsStep({
    super.key,
    required this.title,
    this.subtitle,
    required this.options,
    required this.selected,
    required this.onSelect,
    required this.onNext,
    required this.nextText,
    this.skippable = false,
    this.skipText,
    this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 8.h),

        /// Title
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

        /// OPTIONS
        Wrap(
          spacing: 8.w,
          runSpacing: 8.h,
          children: options.entries.map((entry) {
            final isSelected = entry.key == selected;

            return ChoiceChip(
              label: Text(
                entry.value,
                style: AppTextStyles.getText3(context).copyWith(
                  fontSize: 11.sp,
                  color: isSelected ? Colors.white : AppColors.blackText,
                ),
              ),
              avatar: null,
              showCheckmark: false,
              selected: isSelected,
              selectedColor: AppColors.main,
              backgroundColor: Colors.white,
              shape: StadiumBorder(
                side: BorderSide(
                  color: isSelected
                      ? AppColors.main
                      : AppColors.main.withOpacity(0.35),
                ),
              ),
              onSelected: (_) => onSelect(entry.key),
            );
          }).toList(),
        ),

        const Spacer(),

        /// SKIP BUTTON (same style used in old allergy sheet)
        if (skippable && skipText != null)
          Padding(
            padding: EdgeInsets.only(bottom: 6.h),
            child: HealthGhostButton(
              text: skipText!,
              onTap: onSkip ?? () {},
            ),
          ),

        /// NEXT BUTTON — should match HealthPrimaryButton style
        HealthPrimaryButton(
          text: nextText,
          enabled: selected != null,
          onTap: selected != null ? onNext : null,
        ),

        SizedBox(height: 15.h),
      ],
    );
  }
}
