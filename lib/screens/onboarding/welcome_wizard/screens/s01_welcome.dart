import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../widgets/glass_kit/glass_marble.dart';
import '../widgets/glass_kit/glass_orb_large.dart';
import '../widgets/glass_title.dart';

class S01Welcome extends StatefulWidget {
  final String firstName;
  const S01Welcome({super.key, required this.firstName});

  @override
  State<S01Welcome> createState() => _S01WelcomeState();
}

class _S01WelcomeState extends State<S01Welcome>
    with TickerProviderStateMixin {
  // entrance choreography — one-shot, no looping
  late final AnimationController _entry;

  // background marble bobs (3 marbles)
  late final List<AnimationController> _marbles;

  @override
  void initState() {
    super.initState();
    _entry = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..forward();
    _marbles = [
      AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat(reverse: true),
      AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat(reverse: true),
      AnimationController(vsync: this, duration: const Duration(seconds: 7))..repeat(reverse: true),
    ];
  }

  @override
  void dispose() {
    _entry.dispose();
    for (final c in _marbles) {
      c.dispose();
    }
    super.dispose();
  }

  // staged opacity helpers
  Animation<double> _stage(double startPct, double endPct) =>
      CurvedAnimation(
        parent: _entry,
        curve: Interval(startPct, endPct, curve: Curves.easeOutCubic),
      );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final size = MediaQuery.of(context).size;

    return Stack(
      children: [
        // decorative marbles — bobbing background motion
        AnimatedBuilder(
          animation: _marbles[0],
          builder: (context, _) {
            return PositionedDirectional(
              top: 0.10 * size.height + (-8 * _marbles[0].value),
              start: 0.20 * size.width,
              child: GlassMarble(size: 24.w),
            );
          },
        ),
        AnimatedBuilder(
          animation: _marbles[1],
          builder: (context, _) {
            return PositionedDirectional(
              top: 0.46 * size.height + (10 * _marbles[1].value),
              end: 0.18 * size.width,
              child: GlassMarble(size: 18.w),
            );
          },
        ),
        AnimatedBuilder(
          animation: _marbles[2],
          builder: (context, _) {
            return PositionedDirectional(
              top: 0.36 * size.height + (-12 * _marbles[2].value),
              start: 0.32 * size.width,
              child: GlassMarble(size: 14.w),
            );
          },
        ),

        // logo orb (entrance: fade-up + scale)
        Positioned(
          top: 0.16 * size.height,
          left: 0,
          right: 0,
          child: Center(
            child: AnimatedBuilder(
              animation: _stage(0.10, 0.50),
              builder: (context, child) {
                final t = _stage(0.10, 0.50).value;
                return Opacity(
                  opacity: t,
                  child: Transform.translate(
                    offset: Offset(0, (1 - t) * 18),
                    child: Transform.scale(scale: 0.96 + 0.04 * t, child: child),
                  ),
                );
              },
              child: GlassOrbLarge(
                diameter: 110.w,
                child: SvgPicture.asset(
                  'assets/images/docsera_main.svg',
                  width: 70.w,
                ),
              ),
            ),
          ),
        ),

        // greeting block
        Positioned(
          top: 0.42 * size.height,
          left: 0,
          right: 0,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 22.w),
            child: Column(
              children: [
                FadeTransition(
                  opacity: _stage(0.36, 0.55),
                  child: Text(
                    l.wizard_welcome_salam,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w500,
                      fontSize: 16.sp,
                      letterSpacing: 0.4,
                      color: const Color(0x8C004146), // .55
                    ),
                  ),
                ),
                SizedBox(height: 12.h),
                FadeTransition(
                  opacity: _stage(0.40, 0.65),
                  child: GlassTitle(
                    text: widget.firstName,
                    size: 64,
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: 22.h),
                FadeTransition(
                  opacity: _stage(0.55, 0.75),
                  child: Container(
                    width: 50.w,
                    height: 1.5,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0x00009092),
                          Color(0x73009092),
                          Color(0x00009092),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 14.h),
                FadeTransition(
                  opacity: _stage(0.62, 0.82),
                  child: Text(
                    l.wizard_welcome_tagline,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w700,
                      fontSize: 18.sp,
                      color: const Color(0xFF003A3B),
                    ),
                  ),
                ),
                SizedBox(height: 8.h),
                FadeTransition(
                  opacity: _stage(0.70, 0.92),
                  child: Text(
                    l.wizard_welcome_subline,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w500,
                      fontSize: 13.sp,
                      color: const Color(0xA6004146),
                      height: 1.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
