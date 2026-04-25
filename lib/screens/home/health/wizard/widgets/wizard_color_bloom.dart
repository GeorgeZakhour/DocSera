import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:docsera/app/const.dart';

/// Animated drifting color-bloom background used as the wizard step backdrop.
///
/// Renders two large blurred radial gradients drifting on a 12s loop in
/// opposite directions. The effect is intentionally subtle (8% / 6% opacity).
/// The widget wraps its [child] in a [Stack] so the bloom sits behind the
/// step content.
///
/// Per spec §6.1, this is disabled (static fallback) on low-power hint or
/// older Android — but for v1 we render unconditionally and revisit if perf
/// becomes a concern.
class WizardColorBloom extends StatefulWidget {
  final Widget child;
  const WizardColorBloom({super.key, required this.child});

  @override
  State<WizardColorBloom> createState() => _WizardColorBloomState();
}

class _WizardColorBloomState extends State<WizardColorBloom>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => CustomPaint(
              painter: _BloomPainter(t: _ctrl.value),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _BloomPainter extends CustomPainter {
  final double t;
  _BloomPainter({required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final p1 = Offset(
      size.width * (0.30 + 0.10 * math.sin(t * 2 * math.pi)),
      size.height * (0.25 + 0.08 * math.cos(t * 2 * math.pi)),
    );
    final p2 = Offset(
      size.width * (0.70 + 0.10 * math.cos(t * 2 * math.pi)),
      size.height * (0.65 + 0.08 * math.sin(t * 2 * math.pi)),
    );

    final paint1 = Paint()
      ..shader = RadialGradient(
        colors: [AppColors.main.withValues(alpha: 0.08), Colors.transparent],
      ).createShader(Rect.fromCircle(center: p1, radius: size.width * 0.55))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60);
    final paint2 = Paint()
      ..shader = RadialGradient(
        colors: [AppColors.mainDark.withValues(alpha: 0.06), Colors.transparent],
      ).createShader(Rect.fromCircle(center: p2, radius: size.width * 0.65))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80);

    canvas.drawCircle(p1, size.width * 0.55, paint1);
    canvas.drawCircle(p2, size.width * 0.65, paint2);
  }

  @override
  bool shouldRepaint(covariant _BloomPainter oldDelegate) => oldDelegate.t != t;
}
