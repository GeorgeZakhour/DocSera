import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:docsera/app/const.dart';

/// Floating pill in the bottom-trailing corner. Pulses a soft teal halo every
/// 3.8s. If [label] is non-null, shows the label instead of the chevron
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
      duration: const Duration(milliseconds: 3800),
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
    final buttonSize = 58.h;
    const maxHaloPadding = 14.0;
    return PositionedDirectional(
      bottom: 30.h,
      end: 24.w,
      child: Semantics(
        button: true,
        label: widget.label ??
            MaterialLocalizations.of(context).continueButtonLabel,
        child: SizedBox(
          // Fixed-size hit area accommodating the halo at its largest extent.
          width: hasLabel ? null : buttonSize + maxHaloPadding * 2,
          height: buttonSize + maxHaloPadding * 2,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Halo — sits BEHIND the button, fades + grows in place.
              AnimatedBuilder(
                animation: _pulse,
                builder: (context, _) {
                  final t = _pulse.value;
                  // Halo grows from buttonSize to buttonSize + 2*maxHaloPadding
                  // and fades from .35 to 0.
                  final size = buttonSize + maxHaloPadding * 2 * t;
                  final opacity = (1 - t) * 0.35;
                  return Container(
                    width: hasLabel ? null : size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: hasLabel ? BoxShape.rectangle : BoxShape.circle,
                      borderRadius: hasLabel
                          ? BorderRadius.circular(buttonSize / 2 + maxHaloPadding * t)
                          : null,
                      color: AppColors.main.withValues(alpha: opacity),
                    ),
                  );
                },
              ),
              // The button itself — fixed size, never moves.
              GestureDetector(
                onTap: widget.onTap,
                child: Container(
                  height: buttonSize,
                  padding: hasLabel
                      ? EdgeInsets.symmetric(horizontal: 28.w)
                      : EdgeInsets.zero,
                  constraints: hasLabel
                      ? null
                      : BoxConstraints.tightFor(width: buttonSize, height: buttonSize),
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
            ],
          ),
        ),
      ),
    );
  }
}
