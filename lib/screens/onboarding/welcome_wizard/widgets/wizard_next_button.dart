import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:docsera/app/const.dart';

/// Floating pill in the bottom-trailing corner. Pulses a soft teal halo every
/// 2.6s. If [label] is non-null, shows the label instead of the chevron
/// (used on the closing screen for "Let's begin" / "Done").
class WizardNextButton extends StatefulWidget {
  final VoidCallback onTap;
  final String? label;
  const WizardNextButton({super.key, required this.onTap, this.label});

  @override
  State<WizardNextButton> createState() => _WizardNextButtonState();
}

class _WizardNextButtonState extends State<WizardNextButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasLabel = widget.label != null;
    return PositionedDirectional(
      bottom: 30.h,
      end: 24.w,
      child: Semantics(
        button: true,
        label: widget.label ??
            MaterialLocalizations.of(context).continueButtonLabel,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (context, child) {
              final t = _pulse.value;
              final ringRadius = 12.0 * t;
              final ringOpacity = (1 - t) * 0.35;
              return Container(
                padding: EdgeInsets.all(ringRadius),
                decoration: BoxDecoration(
                  shape: hasLabel ? BoxShape.rectangle : BoxShape.circle,
                  borderRadius: hasLabel ? BorderRadius.circular(40) : null,
                  color: AppColors.main.withValues(alpha: ringOpacity),
                ),
                child: child,
              );
            },
            child: Container(
              height: 58.h,
              padding: hasLabel
                  ? EdgeInsets.symmetric(horizontal: 28.w)
                  : EdgeInsets.zero,
              constraints: hasLabel ? null : BoxConstraints.tightFor(width: 58.w, height: 58.h),
              decoration: BoxDecoration(
                shape: hasLabel ? BoxShape.rectangle : BoxShape.circle,
                borderRadius: hasLabel ? BorderRadius.circular(40) : null,
                color: AppColors.main,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.main.withValues(alpha: 0.55),
                    blurRadius: 30,
                    offset: const Offset(0, 14),
                    spreadRadius: -8,
                  ),
                ],
              ),
              child: Center(
                child: hasLabel
                    ? Text(
                        widget.label!,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w700,
                          fontSize: 14.sp,
                          color: Colors.white,
                        ),
                      )
                    : Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 22.sp),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
