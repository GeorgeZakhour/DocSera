import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../glass_kit/glass_marble.dart';
import '../glass_kit/glass_orb_large.dart';
import 'feature_scaffold.dart' show MarbleSpec;

/// CelebrationScaffold — used for Promotions, Personal Gifts, Earn points,
/// Vouchers. Same orb-stage as Showcase but with sparkles fading in/out
/// around the orb to reinforce the celebratory moment.
class CelebrationScaffold extends StatefulWidget {
  final Widget orbContent;
  final String title;
  final String body;
  final List<MarbleSpec> marbles;
  final List<Offset> sparklePositions; // fractions of (width, height)
  final Widget sparkleIcon;             // a small SVG, sized by parent

  const CelebrationScaffold({
    super.key,
    required this.orbContent,
    required this.title,
    required this.body,
    required this.marbles,
    required this.sparklePositions,
    required this.sparkleIcon,
  });

  @override
  State<CelebrationScaffold> createState() => _CelebrationScaffoldState();
}

class _CelebrationScaffoldState extends State<CelebrationScaffold>
    with TickerProviderStateMixin {
  late final List<AnimationController> _marbleCtrls;
  late final List<AnimationController> _sparkleCtrls;

  @override
  void initState() {
    super.initState();
    _marbleCtrls = widget.marbles.map((spec) {
      final c = AnimationController(vsync: this, duration: spec.period);
      Future.delayed(spec.phaseOffset, () {
        if (mounted) c.repeat(reverse: true);
      });
      return c;
    }).toList();
    _sparkleCtrls = widget.sparklePositions.asMap().entries.map((e) {
      final c = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2500),
      );
      Future.delayed(Duration(milliseconds: 800 * e.key), () {
        if (mounted) c.repeat();
      });
      return c;
    }).toList();
  }

  @override
  void dispose() {
    for (final c in _marbleCtrls) {
      c.dispose();
    }
    for (final c in _sparkleCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Stack(
      children: [
        for (var i = 0; i < widget.marbles.length; i++)
          AnimatedBuilder(
            animation: _marbleCtrls[i],
            builder: (context, child) {
              final t = _marbleCtrls[i].value;
              final dy = -6 * t;
              return PositionedDirectional(
                top: widget.marbles[i].topPct * size.height + dy,
                start: widget.marbles[i].startPct * size.width,
                child: GlassMarble(size: widget.marbles[i].sizePx.w),
              );
            },
          ),

        // sparkles — fade in/out on staggered loops
        for (var i = 0; i < widget.sparklePositions.length; i++)
          AnimatedBuilder(
            animation: _sparkleCtrls[i],
            builder: (context, child) {
              final t = _sparkleCtrls[i].value;
              // 0..0.5: fade in + scale up; 0.5..1.0: fade out + scale down
              final phase = t < 0.5 ? t * 2 : (1 - t) * 2;
              return PositionedDirectional(
                top: widget.sparklePositions[i].dy * size.height,
                start: widget.sparklePositions[i].dx * size.width,
                child: Opacity(
                  opacity: phase,
                  child: Transform.scale(scale: phase, child: child),
                ),
              );
            },
            child: widget.sparkleIcon,
          ),

        // orb-stage hero
        Positioned(
          top: 0.14 * size.height,
          left: 0,
          right: 0,
          child: Center(
            child: GlassOrbLarge(diameter: 200.w, child: widget.orbContent),
          ),
        ),

        // title + body — centered text
        Positioned(
          top: 0.62 * size.height,
          left: 0,
          right: 0,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 22.w),
            child: Column(
              children: [
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w800,
                    fontSize: 28.sp,
                    color: const Color(0xFF003A3B),
                    height: 1.2,
                  ),
                ),
                SizedBox(height: 14.h),
                Text(
                  widget.body,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w500,
                    fontSize: 14.sp,
                    color: const Color(0xC7004146),
                    height: 1.65,
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
