import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Small frosted pill containing text — used for the "step X of Y" indicator
/// floating in the upper-right of Feature-mode screens.
class GlassTag extends StatelessWidget {
  final String text;
  const GlassTag({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(999)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 13.w, vertical: 7.h),
          decoration: BoxDecoration(
            color: const Color(0x99FFFFFF), // white .60
            borderRadius: const BorderRadius.all(Radius.circular(999)),
            border: Border.all(color: const Color(0xD9FFFFFF), width: 1), // .85
          ),
          child: Text(
            text,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w700,
              fontSize: 10.sp,
              letterSpacing: 0.4,
              color: const Color(0xFF007E80),
            ),
          ),
        ),
      ),
    );
  }
}
