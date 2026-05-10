import 'dart:ui';
import 'package:flutter/material.dart';

/// Small floating frosted-glass sphere used as decoration in wizard screens.
///
/// Variation per screen is achieved by passing different `size` + position
/// + animation. The widget itself is just the sphere — positioning and
/// motion are the parent's responsibility.
class GlassMarble extends StatelessWidget {
  final double size; // diameter in logical pixels (already .w-scaled by caller)

  const GlassMarble({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              center: Alignment(-0.4, -0.4),
              radius: 0.85,
              colors: [
                Color(0xEBFFFFFF), // white .92
                Color(0x4DFFFFFF), // white .30
                Color(0x2E009092), // teal .18
              ],
              stops: [0.0, 0.4, 0.8],
            ),
            border: Border.all(
              color: const Color(0xB3FFFFFF), // white .70
              width: 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x38009092), // teal .22
                blurRadius: 14,
                offset: Offset(0, 10),
                spreadRadius: -4,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
