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
    // `opacity` now scales the teal edge tint only — never the white core.
    final tealEdge = (opacity * 0.35).clamp(0.0, 1.0); // very subtle teal tint
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.3, -0.4),
          radius: 0.95,
          colors: [
            const Color(0xCCFFFFFF), // white .80 — core highlight
            const Color(0x4DFFFFFF), // white .30
            AppColors.main.withValues(alpha: tealEdge), // faint teal at edge
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
        border: Border.all(
          color: const Color(0x80FFFFFF), // .50 white border
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0x33009092), // teal .20 — soft cast shadow
            blurRadius: blurSigma * 0.6,
            spreadRadius: blurSigma * 0.1,
            offset: const Offset(0, 12),
          ),
        ],
      ),
    );
  }
}
