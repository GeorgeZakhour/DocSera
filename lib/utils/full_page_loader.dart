import 'dart:math' as math;
import 'package:docsera/app/const.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class FullPageLoader extends StatefulWidget {
  const FullPageLoader({super.key});

  @override
  State<FullPageLoader> createState() => _FullPageLoaderState();
}

class _FullPageLoaderState extends State<FullPageLoader>
    with SingleTickerProviderStateMixin {

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(     // يمنع التفاعل مع العناصر الموجودة تحت اللاودر
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.transparent,    // دائماً شفاف
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (_, child) {
              return Transform.rotate(
                angle: _controller.value * 2 * math.pi,
                child: child,
              );
            },
            child: SvgPicture.asset(
              'assets/images/DocSera-shape-main.svg',
              width: 42,
              height: 42,
              color: AppColors.main,
            ),
          ),
        ),
      ),
    );
  }
}
