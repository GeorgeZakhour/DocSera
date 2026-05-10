import 'dart:ui';
import 'package:flutter/material.dart';

/// Larger frosted capsule placed BEHIND the glass title at z-index lower than
/// the text. Animates with a slow sweep (rotation + horizontal translation)
/// driven by an external [animation].
class GlassShard extends StatelessWidget {
  final double width;
  final double height;
  final Animation<double> animation; // 0..1 looping

  const GlassShard({
    super.key,
    required this.width,
    required this.height,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        // Smooth sin-based oscillation — same end values as the spec mockup.
        final t = animation.value; // 0..1
        // rotation oscillates between -3deg and -1deg
        final rot = (-3 + 2 * (t < 0.5 ? t * 2 : (1 - t) * 2)) * 3.14159 / 180;
        // x oscillates between 0 and -12 logical px
        final dx = -12 * (t < 0.5 ? t * 2 : (1 - t) * 2);
        return Transform.translate(
          offset: Offset(dx, 0),
          child: Transform.rotate(
            angle: rot,
            child: ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(height / 2)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  width: width,
                  height: height,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(height / 2)),
                    color: const Color(0x24FFFFFF), // white .14 (was .22)
                    border: Border.all(color: const Color(0x66FFFFFF), width: 1), // .40 (was .55)
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x2E009092), // teal .18
                        blurRadius: 20,
                        offset: Offset(0, 8),
                        spreadRadius: -6,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
