import 'dart:ui';
import 'package:flutter/material.dart';

/// Large frosted-glass sphere with a strong specular highlight. Used as the
/// hero stage in Showcase + Celebration modes — the feature icon, numerals,
/// QR, gift, etc. live INSIDE the orb.
///
/// Pass a [child] to render inside.
class GlassOrbLarge extends StatelessWidget {
  final double diameter;
  final Widget child;

  const GlassOrbLarge({super.key, required this.diameter, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Container(
              width: diameter,
              height: diameter,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  center: Alignment(-0.3, -0.4),
                  radius: 0.95,
                  colors: [
                    Color(0xEBFFFFFF), // white .92
                    Color(0x4DFFFFFF), // white .30
                    Color(0x33009092), // teal .20
                  ],
                  stops: [0.0, 0.35, 0.8],
                ),
                border: Border.all(color: const Color(0xB3FFFFFF), width: 1),
                boxShadow: const [
                  // outer cast shadow
                  BoxShadow(
                    color: Color(0x61009092), // teal .38
                    blurRadius: 60,
                    offset: Offset(0, 28),
                    spreadRadius: -10,
                  ),
                ],
              ),
              // inner shadows simulated via additional inset overlay
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: Alignment(0.4, 0.5),
                    radius: 0.95,
                    colors: [
                      Color(0x00000000),
                      Color(0x38009092), // teal .22 inset bottom-right
                    ],
                    stops: [0.55, 1.0],
                  ),
                ),
              ),
            ),
          ),
        ),
        // top-left specular highlight
        Positioned(
          top: diameter * 0.11,
          left: diameter * 0.14,
          child: Container(
            width: diameter * 0.32,
            height: diameter * 0.16,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.all(Radius.circular(diameter * 0.16)),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xC7FFFFFF), Color(0x00FFFFFF)],
              ),
            ),
          ),
        ),
        // child sits above the highlight
        Center(child: child),
      ],
    );
  }
}
