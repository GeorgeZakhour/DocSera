import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';

/// Hero card shown at the top of the Health page when the patient hasn't
/// completed their health profile yet.
///
/// Visual language:
///   - Cloudy glass surface: a [_CloudyBackdrop] paints soft blurred teal
///     orbs and a real BackdropFilter blurs them together. A 70%-white
///     glass plane rides on top so content stays sharply readable.
///   - Hero element: the "+15" reward badge is the central visual,
///     not a basic icon. Gradient coin look + sparkle accents.
///   - Title block sits to the side of the badge; full-width primary CTA
///     anchors the bottom.
class CompleteProfileBanner extends StatelessWidget {
  /// Reserved for a future progress indicator. Not rendered in v1.
  final double progress;
  final VoidCallback onTap;

  const CompleteProfileBanner({
    super.key,
    required this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return ClipRRect(
      borderRadius: BorderRadius.circular(22.r),
      child: Stack(
        children: [
          // Cloudy painted backdrop (orbs of color)
          const Positioned.fill(child: _CloudyBackdrop()),

          // Real-blur glass plane on top of the orbs.
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: const SizedBox.shrink(),
            ),
          ),

          // Glass tint + content
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.62),
                  AppColors.background4.withValues(alpha: 0.55),
                ],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.55),
                width: 1.2,
              ),
            ),
            padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 16.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const _RewardBadge(),
                    SizedBox(width: 14.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            t.healthProfile_banner_title,
                            style: AppTextStyles.getTitle2(context).copyWith(
                              color: AppColors.mainDark,
                              height: 1.2,
                              letterSpacing: 0.1,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            t.healthProfile_banner_subtitle,
                            style: AppTextStyles.getText3(context).copyWith(
                              color: AppColors.grayMain,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 14.h),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.main,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(vertical: 11.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          t.healthProfile_banner_cta,
                          style: AppTextStyles.getText2(context).copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.2,
                          ),
                        ),
                        SizedBox(width: 6.w),
                        Icon(
                          Directionality.of(context) == TextDirection.rtl
                              ? Icons.arrow_back_rounded
                              : Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 16.sp,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Cloud-of-color backdrop. Three soft orbs in shifted teal tones —
/// blurred together by a BackdropFilter above to create the "cloudy
/// glass" look the user asked for.
class _CloudyBackdrop extends StatelessWidget {
  const _CloudyBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: Colors.white),
      child: CustomPaint(
        painter: _CloudyOrbsPainter(),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _CloudyOrbsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    void orb(Offset center, double radius, Color color) {
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [color, color.withValues(alpha: 0.0)],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, paint);
    }

    orb(
      Offset(size.width * 0.18, size.height * 0.30),
      size.width * 0.55,
      AppColors.main.withValues(alpha: 0.30),
    );
    orb(
      Offset(size.width * 0.78, size.height * 0.20),
      size.width * 0.50,
      AppColors.background4,
    );
    orb(
      Offset(size.width * 0.62, size.height * 1.05),
      size.width * 0.65,
      AppColors.mainDark.withValues(alpha: 0.22),
    );
  }

  @override
  bool shouldRepaint(covariant _CloudyOrbsPainter oldDelegate) => false;
}

/// Gradient "reward coin" — the eye-catchy hero of the card.
/// Combines a multi-stop gradient disk, a soft outer glow ring, "+15"
/// big and bold, and a sparkle accent in the corner. Pulses gently.
class _RewardBadge extends StatefulWidget {
  const _RewardBadge();

  @override
  State<_RewardBadge> createState() => _RewardBadgeState();
}

class _RewardBadgeState extends State<_RewardBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64.w,
      height: 64.w,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (_, __) {
          final t = _pulse.value;
          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Outer breathing halo
              Container(
                width: 64.w,
                height: 64.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.main.withValues(alpha: 0.18 + 0.08 * t),
                      AppColors.main.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
              // Coin disk
              Container(
                width: 50.w,
                height: 50.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.main, AppColors.mainDark],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.55),
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // The "+15" lockup
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(top: 3.h),
                          child: Text(
                            '+',
                            style: AppTextStyles.getText3(context).copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              height: 1,
                            ),
                          ),
                        ),
                        SizedBox(width: 1.w),
                        Text(
                          '15',
                          style: AppTextStyles.getTitle3(context).copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            height: 1,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Sparkle accent (top-right)
              Positioned(
                top: 0,
                right: 2.w,
                child: Transform.rotate(
                  angle: math.pi / 6 * t,
                  child: Icon(
                    Icons.star_rounded,
                    color: Colors.amber.shade400,
                    size: 14.sp,
                  ),
                ),
              ),
              // Small dot accent (bottom-left)
              Positioned(
                bottom: 4.h,
                left: 2.w,
                child: Container(
                  width: 5.w,
                  height: 5.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.7 + 0.3 * t),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
