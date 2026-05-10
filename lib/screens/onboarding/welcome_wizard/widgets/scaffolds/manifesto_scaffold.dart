import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../glass_kit/glass_marble.dart';
import '../glass_kit/glass_shard.dart';
import '../glass_title.dart';
import 'feature_scaffold.dart' show MarbleSpec; // reuse spec type

/// ManifestoScaffold — used for screens where the title IS the message
/// (Health intro, Loyalty intro, Referral). Larger title (52sp), small
/// icon-tag in the top-trailing corner, fewer marbles, more whitespace.
class ManifestoScaffold extends StatefulWidget {
  final Widget iconTag;     // small 64×64 teal icon tile in top corner
  final String title;
  final String body;
  final List<MarbleSpec> marbles;
  final Widget? extraOverlay;

  const ManifestoScaffold({
    super.key,
    required this.iconTag,
    required this.title,
    required this.body,
    required this.marbles,
    this.extraOverlay,
  });

  @override
  State<ManifestoScaffold> createState() => _ManifestoScaffoldState();
}

class _ManifestoScaffoldState extends State<ManifestoScaffold>
    with TickerProviderStateMixin {
  late final List<AnimationController> _marbleCtrls;
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
    _shardCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Stack(
      children: [
        // icon tag in top corner
        PositionedDirectional(
          top: 0.14 * size.height,
          end: 26.w,
          child: widget.iconTag,
        ),

        for (var i = 0; i < widget.marbles.length; i++)
          AnimatedBuilder(
            animation: _marbleCtrls[i],
            builder: (context, child) {
              final t = _marbleCtrls[i].value;
              final dx = (-6 + i * 3) * t * (i.isEven ? 1 : -1);
              final dy = (-8 + (i * 2)) * t;
              return PositionedDirectional(
                top: widget.marbles[i].topPct * size.height + dy,
                start: widget.marbles[i].startPct * size.width + dx,
                child: GlassMarble(size: widget.marbles[i].sizePx.w),
              );
            },
          ),

        if (widget.extraOverlay != null) widget.extraOverlay!,

        // shard
        Positioned(
          top: 0.32 * size.height,
          right: 30.w,
          child: GlassShard(
            width: 240.w,
            height: 100.h,
            animation: _shardCtrl,
          ),
        ),

        // big title (52sp)
        PositionedDirectional(
          top: 0.28 * size.height,
          start: 22.w,
          end: 22.w,
          child: GlassTitle(text: widget.title, size: 52),
        ),

        // body
        PositionedDirectional(
          top: 0.56 * size.height,
          start: 24.w,
          end: 24.w,
          child: Text(
            widget.body,
            textAlign: TextAlign.start,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w500,
              fontSize: 16.sp,
              color: const Color(0xC7004146),
              height: 1.7,
            ),
          ),
        ),
      ],
    );
  }
}
