import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/app/const.dart';

/// Refined segmented progress bar shown at the top of the wizard.
/// Thin pills, gradient on filled segments, subtle pending segments.
class WizardProgressBar extends StatelessWidget {
  final int totalSteps;
  final int currentIndex; // 0-based

  const WizardProgressBar({
    super.key,
    required this.totalSteps,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 3.h,
      child: Row(
        children: List.generate(totalSteps, (i) {
          final isFilled = i < currentIndex;
          final isActive = i == currentIndex;
          return Expanded(
            child: Padding(
              padding: EdgeInsetsDirectional.only(
                end: i == totalSteps - 1 ? 0 : 3.w,
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: isFilled
                      ? null
                      : isActive
                          ? AppColors.main
                          : AppColors.main.withValues(alpha: 0.10),
                  gradient: isFilled
                      ? const LinearGradient(
                          colors: [AppColors.main, AppColors.mainDark],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
