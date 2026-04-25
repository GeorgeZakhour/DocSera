import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lottie/lottie.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';

/// Final screen shown when the wizard reaches completion. Renders an
/// orchestrated animation sequence — hero Lottie, word-by-word title
/// fade-in, +15 points pill drop (only on first completion), gradient
/// CTA button. The animation is driven by a single AnimationController
/// with Interval children so the sequence stays choreographed, not stitched.
class WizardCompletionScreen extends StatefulWidget {
  final bool alreadyAwarded;
  final VoidCallback onDismiss;
  const WizardCompletionScreen({
    super.key,
    required this.alreadyAwarded,
    required this.onDismiss,
  });

  @override
  State<WizardCompletionScreen> createState() =>
      _WizardCompletionScreenState();
}

class _WizardCompletionScreenState extends State<WizardCompletionScreen>
    with TickerProviderStateMixin {
  late final AnimationController _master;
  late final AnimationController _bloom;

  @override
  void initState() {
    super.initState();
    _master = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    );
    _bloom = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
    _start();
  }

  Future<void> _start() async {
    HapticFeedback.mediumImpact();
    _master.forward();
    if (!widget.alreadyAwarded) {
      await Future.delayed(const Duration(milliseconds: 1800));
      if (mounted) HapticFeedback.lightImpact();
    }
  }

  @override
  void dispose() {
    _master.dispose();
    _bloom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final words = t.healthProfile_completion_title.split(' ');

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _bloom,
              builder: (_, __) => CustomPaint(
                painter: _CompletionBloomPainter(_bloom.value),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: 40.h),
                  // Hero — custom celebration composition under the Lottie.
                  // The empty placeholder JSON renders nothing, so the
                  // composition shows. A real Lottie (when added) covers it.
                  SizedBox(
                    width: 220.w,
                    height: 220.w,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        _CelebrationHero(controller: _master),
                        Lottie.asset(
                          'assets/lottie/health_profile/completion_hero.json',
                          repeat: false,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24.h),
                  // Word-staggered title
                  AnimatedBuilder(
                    animation: _master,
                    builder: (_, __) => Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8.w,
                      children: List.generate(words.length, (i) {
                        final start = 0.30 + (i * 0.04);
                        final t1 = ((_master.value - start) * 6).clamp(0.0, 1.0);
                        return Opacity(
                          opacity: t1,
                          child: Transform.translate(
                            offset: Offset(0, (1 - t1) * 8),
                            child: Text(
                              words[i],
                              style: AppTextStyles.getTitle1(context).copyWith(
                                fontSize: 24.sp,
                                color: AppColors.mainDark,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  SizedBox(height: 14.h),
                  if (!widget.alreadyAwarded)
                    _PointsPill(
                      controller: _master,
                      text: t.healthProfile_pointsAwarded,
                    ),
                  SizedBox(height: 14.h),
                  Text(
                    widget.alreadyAwarded
                        ? t.healthProfile_completion_alreadyBody
                        : t.healthProfile_completion_body,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.getText2(context).copyWith(
                      color: AppColors.grayMain,
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: widget.onDismiss,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.main,
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                      ),
                      child: Text(
                        t.healthProfile_completion_cta,
                        style: AppTextStyles.getText1(context).copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 16.h),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Glass pill that drops in from above with a bounce, only rendered on
/// first completion (alreadyAwarded == false).
class _PointsPill extends StatelessWidget {
  final AnimationController controller;
  final String text;
  const _PointsPill({required this.controller, required this.text});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        // Begin around master.value = 0.55 (after the hero finishes drawing)
        final t1 = ((controller.value - 0.55) * 4).clamp(0.0, 1.0);
        // Soft bounce — sin curve in [0..1]
        final bounce = math.sin(t1 * math.pi) * 6;
        return Opacity(
          opacity: t1,
          child: Transform.translate(
            offset: Offset(0, -40 * (1 - t1) - bounce),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  AppColors.main.withValues(alpha: 0.18),
                  AppColors.mainDark.withValues(alpha: 0.18),
                ]),
                border: Border.all(
                  color: AppColors.main.withValues(alpha: 0.4),
                  width: 0.8,
                ),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star_rounded, color: AppColors.main, size: 16.sp),
                  SizedBox(width: 6.w),
                  Text(
                    text,
                    style: AppTextStyles.getText1(context).copyWith(
                      color: AppColors.mainDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Drifting blurred radial gradient backdrop for the completion screen.
/// Same approach as WizardColorBloom but with slightly higher opacity to
/// celebrate the moment.
class _CompletionBloomPainter extends CustomPainter {
  final double t;
  _CompletionBloomPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final p1 = Offset(
      size.width * (0.30 + 0.10 * math.sin(t * 2 * math.pi)),
      size.height * 0.30,
    );
    final p2 = Offset(
      size.width * (0.70 + 0.10 * math.cos(t * 2 * math.pi)),
      size.height * 0.70,
    );
    canvas.drawCircle(
      p1,
      size.width * 0.55,
      Paint()
        ..color = AppColors.main.withValues(alpha: 0.10)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60),
    );
    canvas.drawCircle(
      p2,
      size.width * 0.65,
      Paint()
        ..color = AppColors.mainDark.withValues(alpha: 0.08)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80),
    );
  }

  @override
  bool shouldRepaint(covariant _CompletionBloomPainter oldDelegate) =>
      oldDelegate.t != t;
}

/// Celebration composition shown when no real Lottie hero is provided.
///
/// Layered build: outer breathing halo, inner gradient disk, white
/// check at the centre, sparkle accents drifting around the disk.
/// Driven by the same master controller so it choreographs with the
/// rest of the screen.
class _CelebrationHero extends StatelessWidget {
  final AnimationController controller;
  const _CelebrationHero({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        // Disk grows in over the first 35% of the master timeline.
        final diskT =
            (controller.value / 0.35).clamp(0.0, 1.0);
        // Check mark scales in from 0.20 to 0.50 of the timeline.
        final checkT =
            ((controller.value - 0.20) / 0.30).clamp(0.0, 1.0);
        // Sparkle pulse — gentle, continuous.
        final sparkleT = controller.value;

        return Stack(
          alignment: Alignment.center,
          children: [
            // Outer halo
            Transform.scale(
              scale: 0.85 + 0.15 * diskT,
              child: Container(
                width: 200.w,
                height: 200.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.main.withValues(alpha: 0.18 * diskT),
                      AppColors.main.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            // Coin disk
            Transform.scale(
              scale: Curves.easeOutBack.transform(diskT),
              child: Container(
                width: 140.w,
                height: 140.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.main, AppColors.mainDark],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.55),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          AppColors.mainDark.withValues(alpha: 0.20 * diskT),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Transform.scale(
                  scale: Curves.elasticOut.transform(checkT.clamp(0.0, 1.0)),
                  child: Icon(
                    Icons.check_rounded,
                    size: 78.sp,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            // Sparkle accents — top-right, top-left, bottom
            _Sparkle(
              top: 4.h,
              right: 18.w,
              size: 22.sp,
              t: sparkleT,
              phase: 0.0,
            ),
            _Sparkle(
              top: 14.h,
              left: 18.w,
              size: 14.sp,
              t: sparkleT,
              phase: 0.4,
            ),
            _Sparkle(
              bottom: 18.h,
              right: 38.w,
              size: 12.sp,
              t: sparkleT,
              phase: 0.7,
            ),
          ],
        );
      },
    );
  }
}

class _Sparkle extends StatelessWidget {
  final double? top;
  final double? bottom;
  final double? left;
  final double? right;
  final double size;
  final double t;
  final double phase;
  const _Sparkle({
    this.top,
    this.bottom,
    this.left,
    this.right,
    required this.size,
    required this.t,
    required this.phase,
  });

  @override
  Widget build(BuildContext context) {
    final twinkle = (math.sin((t + phase) * 2 * math.pi) + 1) / 2;
    final opacity = 0.45 + 0.55 * twinkle;
    final scale = 0.85 + 0.25 * twinkle;
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Opacity(
        opacity: opacity,
        child: Transform.scale(
          scale: scale,
          child: Icon(
            Icons.auto_awesome_rounded,
            color: Colors.amber.shade400,
            size: size,
          ),
        ),
      ),
    );
  }
}
