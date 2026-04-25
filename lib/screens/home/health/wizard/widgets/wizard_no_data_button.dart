import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/app/const.dart';

/// Outlined "No allergy / No condition / etc." button shown at the bottom
/// of multi-select wizard sections. Auto-hides via cross-fade + slide when
/// at least one item is selected.
///
/// Per spec §3.4: when [anySelected] becomes true the button cross-fades
/// out (200ms) and slides 8px down. Reverse on uncheck.
class WizardNoDataButton extends StatelessWidget {
  final String label;
  final bool anySelected;
  final VoidCallback onTap;

  const WizardNoDataButton({
    super.key,
    required this.label,
    required this.anySelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, anim) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.2),
          end: Offset.zero,
        ).animate(anim),
        child: FadeTransition(opacity: anim, child: child),
      ),
      child: anySelected
          ? const SizedBox.shrink()
          : InkWell(
              key: const ValueKey('visible'),
              onTap: onTap,
              borderRadius: BorderRadius.circular(12.r),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 14.h),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: AppColors.main.withValues(alpha: 0.35),
                  ),
                  color: AppColors.main.withValues(alpha: 0.04),
                ),
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: AppColors.main,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
