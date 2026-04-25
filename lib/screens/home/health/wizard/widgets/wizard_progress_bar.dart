import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/app/const.dart';

/// Segmented progress bar shown at the top of the wizard.
///
/// - Filled segments use a teal → mainDark gradient.
/// - The current segment uses a half-opacity teal to indicate "in-progress".
/// - Pending segments use a low-opacity teal background.
///
/// The animation is on each segment's color/gradient transition (450ms),
/// not on per-segment shimmer — that can be added later if needed.
class WizardProgressBar extends StatelessWidget {
  final int totalSteps;
  final int currentIndex; // 0-based; segment at currentIndex is the "active"

  const WizardProgressBar({
    super.key,
    required this.totalSteps,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 4.h,
      child: Row(
        children: List.generate(totalSteps, (i) {
          final isFilled = i < currentIndex;
          final isActive = i == currentIndex;
          return Expanded(
            child: Padding(
              padding: EdgeInsetsDirectional.only(
                end: i == totalSteps - 1 ? 0 : 2.w,
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: isFilled
                      ? null // gradient takes over below
                      : isActive
                          ? AppColors.main.withValues(alpha: 0.55)
                          : AppColors.main.withValues(alpha: 0.12),
                  gradient: isFilled
                      ? const LinearGradient(
                          colors: [AppColors.main, AppColors.mainDark],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
