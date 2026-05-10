import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../glass_kit/glass_marble.dart';
import '../glass_kit/glass_orb_large.dart';
import 'feature_scaffold.dart' show MarbleSpec;

/// ShowcaseScaffold — used for opener (01) and closer (18). Large glass orb
/// holds the hero (logo, brand mark). Content beneath: title + tagline +
/// subline.
class ShowcaseScaffold extends StatefulWidget {
  final Widget orbContent;            // sits inside the GlassOrbLarge
  final Widget? aboveTitle;           // e.g. small "أهلاً" salam line
  final Widget title;                  // typically GlassTitle
  final String? tagline;
  final String? subline;
  final List<MarbleSpec> marbles;

  const ShowcaseScaffold({
    super.key,
    required this.orbContent,
    this.aboveTitle,
    required this.title,
    this.tagline,
    this.subline,
    this.marbles = const [],
  });

  @override
  State<ShowcaseScaffold> createState() => _ShowcaseScaffoldState();
}

class _ShowcaseScaffoldState extends State<ShowcaseScaffold>
    with TickerProviderStateMixin {
  late final List<AnimationController> _marbleCtrls;

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
  }

  @override
  void dispose() {
    for (final c in _marbleCtrls) {
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
              final dy = -8 * t;
              return PositionedDirectional(
                top: widget.marbles[i].topPct * size.height + dy,
                start: widget.marbles[i].startPct * size.width,
                child: GlassMarble(size: widget.marbles[i].sizePx.w),
              );
            },
          ),

        // hero orb
        Positioned(
          top: 0.16 * size.height,
          left: 0,
          right: 0,
          child: Center(
            child: GlassOrbLarge(diameter: 210.w, child: widget.orbContent),
          ),
        ),

        // content stack — centered
        Positioned(
          top: 0.55 * size.height,
          left: 0,
          right: 0,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 22.w),
            child: Column(
              children: [
                if (widget.aboveTitle != null) widget.aboveTitle!,
                SizedBox(height: 12.h),
                widget.title,
                if (widget.tagline != null) ...[
                  SizedBox(height: 14.h),
                  Text(
                    widget.tagline!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w700,
                      fontSize: 18.sp,
                      color: const Color(0xFF003A3B),
                      height: 1.4,
                    ),
                  ),
                ],
                if (widget.subline != null) ...[
                  SizedBox(height: 8.h),
                  Text(
                    widget.subline!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w500,
                      fontSize: 13.sp,
                      color: const Color(0xA6004146), // .65
                      height: 1.6,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
