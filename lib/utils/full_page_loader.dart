import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:docsera/app/const.dart';

class FullPageLoader extends StatefulWidget {
  const FullPageLoader({
    super.key,
    this.fullscreen = false,
    this.size = 42,
    this.blockInteraction = false,
  });

  /// إذا true → يغطي المساحة المتاحة (Overlay)
  /// إذا false → يظهر بحجمه الطبيعي فقط
  final bool fullscreen;

  /// حجم الأيقونة
  final double size;

  /// يمنع التفاعل مع العناصر تحت اللاودر
  final bool blockInteraction;

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

  Widget _buildLoader() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, child) {
        return Transform.rotate(
          angle: _controller.value * 2 * math.pi,
          child: child,
        );
      },
      child: SvgPicture.asset(
        'assets/images/DocSera-shape-main.svg',
        width: widget.size,
        height: widget.size,
        color: AppColors.main,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loader = Center(child: _buildLoader());

    // 🔹 Inline / داخل content
    if (!widget.fullscreen) {
      return widget.blockInteraction
          ? IgnorePointer(child: loader)
          : loader;
    }

    // 🔹 Full overlay (بدون فرض constraints)
    return Stack(
      children: [
        Positioned.fill(
          child: widget.blockInteraction
              ? IgnorePointer(child: Container(color: Colors.transparent))
              : const SizedBox.shrink(),
        ),
        Positioned.fill(child: loader),
      ],
    );
  }
}
