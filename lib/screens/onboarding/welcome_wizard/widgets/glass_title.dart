import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Cairo title rendered as translucent teal glass via a ShaderMask.
///
/// Recipe (from spec):
/// - Cairo weight 900, 46sp default (manifesto: 52sp via [size]).
/// - Line-height 1.18 — Arabic descenders need the headroom.
/// - Translucent teal gradient clipped to the text shape.
/// - Outer drop-shadow on the wrapping container — NO inner white shadow
///   (the white-shadow recipe creates speckles inside Arabic counters).
class GlassTitle extends StatelessWidget {
  final String text;
  final double size; // sp before .sp scaling
  final TextAlign textAlign;

  const GlassTitle({
    super.key,
    required this.text,
    this.size = 46,
    this.textAlign = TextAlign.right,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        boxShadow: [
          // Very faint, symmetric (no offset) glow — replaces the previous
          // block-shaped shadow. Spreads softly around the title without
          // forming a rectangular block behind it.
          BoxShadow(
            color: Color(0x14009092), // teal .08 — barely there
            blurRadius: 32,
            spreadRadius: -10,
          ),
        ],
      ),
      child: ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF4DD0D2), // light teal — top sheen
            Color(0xF2009092), // teal .95
            Color(0xE6009092), // teal .90 — bottom (was .75 — fixes white edges)
          ],
          stops: [0.0, 0.25, 1.0],
        ).createShader(bounds),
        blendMode: BlendMode.srcIn,
        child: Text(
          text,
          textAlign: textAlign,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w900,
            fontSize: size.sp,
            height: 1.18,
            letterSpacing: -0.4,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
