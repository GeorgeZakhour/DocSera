import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:docsera/app/const.dart';

/// Animated dot indicators. The active dot extends into a pill shape.
/// Tapping a dot calls [onJump] with that index.
class WizardPageDots extends StatelessWidget {
  final int total;
  final int current;
  final ValueChanged<int> onJump;

  const WizardPageDots({
    super.key,
    required this.total,
    required this.current,
    required this.onJump,
  });

  @override
  Widget build(BuildContext context) {
    return PositionedDirectional(
      bottom: 50.h,
      start: 26.w,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(total, (i) {
          final isActive = i == current;
          return Padding(
            padding: EdgeInsetsDirectional.only(end: 7.w),
            child: Semantics(
              button: true,
              label: 'Page ${i + 1} of $total',
              selected: isActive,
              child: GestureDetector(
                onTap: () => onJump(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOut,
                  width: isActive ? 24.w : 6.w,
                  height: 6.h,
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.main
                        : AppColors.main.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
