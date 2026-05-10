import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:docsera/app/const.dart';

/// Always-on backdrop layer for every wizard screen — mint gradient + two
/// large drifting orbs + an optional accent orb directly behind the title
/// position. Orbs animate on independent multi-second loops via sin/cos.
class WizardBackground extends StatefulWidget {
  /// If true, renders an additional teal accent orb at ~44% screen height,
  /// near the right edge — gives Feature/Manifesto titles color to refract
  /// through.
  final bool withTitleAccent;

  const WizardBackground({super.key, this.withTitleAccent = true});

  @override
  State<WizardBackground> createState() => _WizardBackgroundState();
}

class _WizardBackgroundState extends State<WizardBackground>
    with TickerProviderStateMixin {
  late final AnimationController _ctrlA;
  late final AnimationController _ctrlB;
  late final AnimationController _ctrlC;

  @override
  void initState() {
    super.initState();
    _ctrlA = AnimationController(vsync: this, duration: const Duration(seconds: 18))..repeat();
    _ctrlB = AnimationController(vsync: this, duration: const Duration(seconds: 22))..repeat();
    _ctrlC = AnimationController(vsync: this, duration: const Duration(seconds: 14))..repeat();
  }

  @override
  void dispose() {
    _ctrlA.dispose();
    _ctrlB.dispose();
    _ctrlC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // mint gradient base
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFF1FBF8), Color(0xFFE0F4F0)],
              ),
            ),
          ),
        ),
        // orb A — top-right
        AnimatedBuilder(
          animation: _ctrlA,
          builder: (context, _) {
            final t = _ctrlA.value * 2 * math.pi;
            return Positioned(
              top: -90.h + math.sin(t) * 18.h,
              right: -100.w + math.cos(t) * 12.w,
              child: _orb(diameter: 320.w, opacity: 0.30),
            );
          },
        ),
        // orb B — bottom-left
        AnimatedBuilder(
          animation: _ctrlB,
          builder: (context, _) {
            final t = _ctrlB.value * 2 * math.pi;
            return Positioned(
              bottom: 60.h + math.sin(t) * 14.h,
              left: -80.w + math.cos(t) * 16.w,
              child: _orb(diameter: 250.w, opacity: 0.22),
            );
          },
        ),
        // orb C — title accent
        if (widget.withTitleAccent)
          AnimatedBuilder(
            animation: _ctrlC,
            builder: (context, _) {
              final t = _ctrlC.value * 2 * math.pi;
              return Positioned(
                top: 0.44 * MediaQuery.of(context).size.height +
                    math.sin(t) * 12.h,
                right: -40.w + math.cos(t) * 10.w,
                child: _orb(diameter: 220.w, opacity: 0.30, blurSigma: 60),
              );
            },
          ),
      ],
    );
  }

  Widget _orb({required double diameter, required double opacity, double blurSigma = 48}) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.main.withValues(alpha: opacity),
        boxShadow: [
          BoxShadow(
            color: AppColors.main.withValues(alpha: opacity),
            blurRadius: blurSigma,
            spreadRadius: blurSigma * 0.4,
          ),
        ],
      ),
    );
  }
}
