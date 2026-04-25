import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';

class SingleSelectOption<T> {
  final T value;
  final String label;
  const SingleSelectOption({required this.value, required this.label});
}

/// Reusable single-select list with subtle row styling and gradient
/// active-indicator stripe. Used by every wizard "pick one" step.
class WizardSingleSelectList<T> extends StatelessWidget {
  final List<SingleSelectOption<T>> options;
  final T? selected;
  final ValueChanged<T> onChanged;

  const WizardSingleSelectList({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.main.withValues(alpha: 0.18)),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        children: [
          for (int i = 0; i < options.length; i++)
            _Row<T>(
              option: options[i],
              isSelected: options[i].value == selected,
              isLast: i == options.length - 1,
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(options[i].value);
              },
            ),
        ],
      ),
    );
  }
}

class _Row<T> extends StatelessWidget {
  final SingleSelectOption<T> option;
  final bool isSelected;
  final bool isLast;
  final VoidCallback onTap;
  const _Row({
    required this.option,
    required this.isSelected,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.main.withValues(alpha: 0.06) : null,
          border: isLast
              ? null
              : Border(
                  bottom: BorderSide(
                    color: AppColors.main.withValues(alpha: 0.10),
                  ),
                ),
        ),
        child: Row(
          children: [
            if (isSelected)
              Container(
                width: 3,
                height: 24.h,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.main, AppColors.mainDark],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              )
            else
              const SizedBox(width: 3),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                option.label,
                style: AppTextStyles.getText1(context).copyWith(
                  color: isSelected ? AppColors.mainDark : AppColors.blackText,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
