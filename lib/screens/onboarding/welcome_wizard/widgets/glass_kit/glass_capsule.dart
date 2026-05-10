import 'dart:ui';
import 'package:flutter/material.dart';

/// Frosted pill-shaped surface, typically rotated and used under the hero
/// icon in Feature mode to give the icon a glass platform.
class GlassCapsule extends StatelessWidget {
  final double width;
  final double height;
  final double rotation; // radians

  const GlassCapsule({
    super.key,
    required this.width,
    required this.height,
    this.rotation = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotation,
      child: ClipRRect(
        borderRadius: BorderRadius.all(Radius.circular(height / 2)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.all(Radius.circular(height / 2)),
              color: const Color(0x80FFFFFF), // white .50
              border: Border.all(color: const Color(0xC7FFFFFF), width: 1), // .78
              boxShadow: const [
                BoxShadow(
                  color: Color(0x47009092), // teal .28
                  blurRadius: 22,
                  offset: Offset(0, 12),
                  spreadRadius: -8,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
