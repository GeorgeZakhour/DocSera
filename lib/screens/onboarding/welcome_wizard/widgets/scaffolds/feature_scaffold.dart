import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../glass_kit/glass_capsule.dart';
import '../glass_kit/glass_marble.dart';
import '../glass_kit/glass_shard.dart';
import '../glass_kit/glass_tag.dart';
import '../glass_title.dart';

/// Position of a marble: percentages of screen width/height + size + per-
/// marble animation phase (so they don't sync).
class MarbleSpec {
  final double topPct;       // 0..1 — vertical position
  final double startPct;     // 0..1 — start (right in RTL, left in LTR)
  final double sizePx;       // logical px (scaled by .w outside)
  final Duration period;     // bob duration
  final Duration phaseOffset; // start delay

  const MarbleSpec({
    required this.topPct,
    required this.startPct,
    required this.sizePx,
    required this.period,
    this.phaseOffset = Duration.zero,
  });
}

class CapsuleSpec {
  final double topPct;
  final double startPct;
  final double widthPx;
  final double heightPx;
  final double rotation; // radians
  const CapsuleSpec({
    required this.topPct,
    required this.startPct,
    required this.widthPx,
    required this.heightPx,
    required this.rotation,
  });
}

/// FeatureScaffold — workhorse layout for ~10 wizard screens.
///
/// Composition (RTL-first, end-side = right in AR, mirrors in LTR):
/// - Step tag in upper-trailing corner
/// - Hero icon in upper area (centerish), with rotated capsule under it
/// - 4 marbles scattered around the hero
/// - Glass shard behind the title
/// - Glass title at ~46% of screen height
/// - Body text below the title
/// - The Wizard's skip/dots/next chrome is added by the parent screen.
class FeatureScaffold extends StatefulWidget {
  final Widget heroIcon; // size already configured by caller
  final String stepTagText;
  final String title;
  final String body;
  final List<MarbleSpec> marbles;     // exactly 4 expected, but flexible
  final CapsuleSpec capsule;
  final Widget? extraTopOverlay;       // optional per-screen signature motion overlay
  final Widget? customTitle;           // when non-null, replaces GlassTitle (e.g. for badged titles)

  const FeatureScaffold({
    super.key,
    required this.heroIcon,
    required this.stepTagText,
    required this.title,
    required this.body,
    required this.marbles,
    required this.capsule,
    this.extraTopOverlay,
    this.customTitle,
  });

  @override
  State<FeatureScaffold> createState() => _FeatureScaffoldState();
}

class _FeatureScaffoldState extends State<FeatureScaffold>
    with TickerProviderStateMixin {
  late final List<AnimationController> _marbleCtrls;
  late final AnimationController _capsuleCtrl;
  late final AnimationController _heroCtrl;
  late final AnimationController _shardCtrl;

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
    _capsuleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5500),
    )..repeat(reverse: true);
    _heroCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4500),
    )..repeat(reverse: true);
    _shardCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 8000),
    )..repeat();
  }

  @override
  void dispose() {
    for (final c in _marbleCtrls) {
      c.dispose();
    }
    _capsuleCtrl.dispose();
    _heroCtrl.dispose();
    _shardCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Stack(
      children: [
        // Step tag — upper-trailing
        PositionedDirectional(
          top: 0.08 * size.height,
          end: 0.14 * size.width,
          child: GlassTag(text: widget.stepTagText),
        ),

        // 4 marbles, each on its own bobbing keyframe
        for (var i = 0; i < widget.marbles.length; i++)
          AnimatedBuilder(
            animation: _marbleCtrls[i],
            builder: (context, child) {
              final t = _marbleCtrls[i].value;
              final dx = (-8 + i * 4) * t * (i.isEven ? 1 : -1);
              final dy = (-10 + (i * 3)) * t;
              return PositionedDirectional(
                top: widget.marbles[i].topPct * size.height + dy,
                end: widget.marbles[i].startPct * size.width + dx,
                child: GlassMarble(size: widget.marbles[i].sizePx.w),
              );
            },
          ),

        // Capsule under the hero icon — rotates and bobs
        AnimatedBuilder(
          animation: _capsuleCtrl,
          builder: (context, child) {
            final t = _capsuleCtrl.value;
            final extraRot = (1 - t.abs()) * 6 * 3.14159 / 180;
            final dy = -4 * t;
            return PositionedDirectional(
              top: widget.capsule.topPct * size.height + dy,
              end: widget.capsule.startPct * size.width,
              child: Transform.rotate(
                angle: widget.capsule.rotation + extraRot,
                child: GlassCapsule(
                  width: widget.capsule.widthPx.w,
                  height: widget.capsule.heightPx.h,
                ),
              ),
            );
          },
        ),

        // Hero icon — bobs subtly
        AnimatedBuilder(
          animation: _heroCtrl,
          builder: (context, child) {
            final t = _heroCtrl.value;
            final dy = -5 * t;
            final rot = (-6 + 3 * t) * 3.14159 / 180;
            return Positioned(
              top: 0.16 * size.height + dy,
              left: 0,
              right: 0,
              child: Center(
                child: Transform.rotate(angle: rot, child: child),
              ),
            );
          },
          child: widget.heroIcon,
        ),

        // Optional per-screen signature overlay
        if (widget.extraTopOverlay != null) widget.extraTopOverlay!,

        // Glass shard behind the title
        Positioned(
          top: 0.50 * size.height,
          right: 30.w,
          child: GlassShard(
            width: 220.w,
            height: 90.h,
            animation: _shardCtrl,
          ),
        ),

        // Title (custom widget if provided, else default GlassTitle)
        PositionedDirectional(
          top: 0.46 * size.height,
          start: 22.w,
          end: 22.w,
          child: widget.customTitle ?? GlassTitle(text: widget.title, size: 46),
        ),

        // Body
        PositionedDirectional(
          top: 0.70 * size.height,
          start: 24.w,
          end: 24.w,
          child: Text(
            widget.body,
            textAlign: TextAlign.start,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w500,
              fontSize: 15.sp,
              color: const Color(0xC7004146), // teal-near-black .78
              height: 1.65,
            ),
          ),
        ),
      ],
    );
  }
}
