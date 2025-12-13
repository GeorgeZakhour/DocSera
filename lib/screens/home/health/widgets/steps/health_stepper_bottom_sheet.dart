import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/screens/home/health/widgets/health_step_header.dart';

/// ===============================================================
///  HEALTH STEPPER BOTTOM SHEET (GENERIC)
///  Replaces all Add-* bottom sheets (Allergies, Surgeries…)
/// ===============================================================
///
///  Usage:
///  HealthStepperBottomSheet(
///    steps: [
///      Step 1 Widget,
///      Step 2 Widget,
///      Step 3 Widget,
///      Step 4 Widget,
///    ],
///    titles: [
///      t.step1_title,
///      t.step2_title,
///      t.step3_title,
///      t.step4_title,
///    ],
///    step: currentStep,
///    onNext: () {},
///    onBack: () {},
///  )
///
class HealthStepperBottomSheet extends StatelessWidget {
  /// عدد الخطوات (widgets)
  final List<Widget> steps;

  /// عناوين الخطوات فوق الهيدر — ARB strings
  final List<String> titles;

  /// رقم الخطوة الحالية (1-indexed مثل نظام الحساسية القديم)
  final int step;

  /// عند الضغط على زر الرجوع في الهيدر
  final VoidCallback onBack;

  /// عند الانتقال للخطوة التالية (عادةً داخل الـ step نفسه)
  final VoidCallback? onNext;

  /// للتحكم في ارتفاع sheet
  final double initialSize;
  final double minSize;
  final double maxSize;

  const HealthStepperBottomSheet({
    super.key,
    required this.steps,
    required this.titles,
    required this.step,
    required this.onBack,
    this.onNext,
    this.initialSize = 0.92,
    this.minSize = 0.40,
    this.maxSize = 0.92,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: initialSize,
      minChildSize: minSize,
      maxChildSize: maxSize,
      builder: (_, controller) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.background2,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
          ),

          padding: EdgeInsets.only(
            left: 16.w,
            right: 16.w,
            top: 12.h,
            bottom: MediaQuery.of(context).viewInsets.bottom + 12.h,
          ),

          child: Column(
            children: [
              /// ---------- STEP HEADER ----------
              HealthStepHeader(
                titles: titles,
                step: step,
                onBack: onBack,
              ),

              SizedBox(height: 12.h),

              /// ---------- STEP CONTENT ----------
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: steps[step - 1],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
