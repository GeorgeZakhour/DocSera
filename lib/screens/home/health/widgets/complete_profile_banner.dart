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
/// Design language:
///   - Multi-orb cloudy backdrop, real BackdropFilter blur, then a tinted
///     glass plane for content legibility (white→teal gradient).
///   - Hairline gradient border + soft outer glow give a "lifted glass"
///     edge so the card feels detached from the page beneath it.
///   - Floating reward badge anchors a vertical lockup; CTA pill spans
///     the bottom with a directional chevron in the reading direction.
class CompleteProfileBanner extends StatefulWidget {
  /// Reserved for a future progress indicator. Not rendered in v1.
  final double progress;
  final VoidCallback onTap;

  const CompleteProfileBanner({
    super.key,
    required this.progress,
    required this.onTap,
  });

  @override
  State<CompleteProfileBanner> createState() => _CompleteProfileBannerState();
}

class _CompleteProfileBannerState extends State<CompleteProfileBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entry;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _entry = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );
    _fade = CurvedAnimation(parent: _entry, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entry, curve: Curves.easeOutCubic));
    _scale = Tween<double>(begin: 0.96, end: 1.0)
        .animate(CurvedAnimation(parent: _entry, curve: Curves.easeOutCubic));

    // Tiny delay so the page settles before the card glides in.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _entry.forward();
    });
  }

  @override
  void dispose() {
    _entry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: ScaleTransition(
          scale: _scale,
          child: _buildBanner(context, t, isRtl),
        ),
      ),
    );
  }

  Widget _buildBanner(BuildContext context, AppLocalizations t, bool isRtl) {
    return DecoratedBox(
      // Soft outer halo so the card lifts off the page.
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: AppColors.main.withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: AppColors.mainDark.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24.r),
        child: Stack(
          children: [
            // Painted orbs of color in the back.
            const Positioned.fill(child: _CloudyBackdrop()),

            // Real-blur glass plane.
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                child: const SizedBox.shrink(),
              ),
            ),

            // Decorative floating mini-orbs (sit on top of blur, very subtle).
            const Positioned.fill(child: _FloatingDecor()),

            // Tinted glass plane + content
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.70),
                    AppColors.background4.withValues(alpha: 0.55),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.65),
                  width: 1.2,
                ),
              ),
              padding: EdgeInsets.fromLTRB(18.w, 18.h, 18.w, 16.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Hero row: floating badge + title block ──
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const _RewardBadge(),
                      SizedBox(width: 16.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              t.healthProfile_banner_title,
                              style: AppTextStyles.getTitle2(context).copyWith(
                                color: AppColors.mainDark,
                                fontWeight: FontWeight.w800,
                                height: 1.2,
                                letterSpacing: 0.1,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 6.h),
                            // Subtitle pill — a small chip with a spark
                            // icon makes the reward feel like an offer
                            // rather than a plain line of text.
                            _RewardChip(text: t.healthProfile_banner_subtitle),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),

                  // ── Hairline glass divider ──
                  Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.0),
                          Colors.white.withValues(alpha: 0.7),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 14.h),

                  // ── CTA: gradient pill with directional chevron ──
                  _PrimaryCta(
                    label: t.healthProfile_banner_cta,
                    isRtl: isRtl,
                    onTap: widget.onTap,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Decor: outer cloudy backdrop ─────────────────────────────────────────

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
      AppColors.main.withValues(alpha: 0.34),
    );
    orb(
      Offset(size.width * 0.78, size.height * 0.22),
      size.width * 0.50,
      AppColors.background4,
    );
    orb(
      Offset(size.width * 0.62, size.height * 1.05),
      size.width * 0.65,
      AppColors.mainDark.withValues(alpha: 0.22),
    );
    // Tiny warm accent so the card isn't monochrome.
    orb(
      Offset(size.width * 0.92, size.height * 0.85),
      size.width * 0.30,
      AppColors.yellow.withValues(alpha: 0.10),
    );
  }

  @override
  bool shouldRepaint(covariant _CloudyOrbsPainter oldDelegate) => false;
}

// ─── Decor: subtle floating dots / sparkles on top of the glass ───────────

class _FloatingDecor extends StatefulWidget {
  const _FloatingDecor();

  @override
  State<_FloatingDecor> createState() => _FloatingDecorState();
}

class _FloatingDecorState extends State<_FloatingDecor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4500),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          return CustomPaint(
            painter: _SparklePainter(_c.value),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}

class _SparklePainter extends CustomPainter {
  final double t;
  _SparklePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    void dot(Offset c, double r, double opacity) {
      final paint = Paint()..color = Colors.white.withValues(alpha: opacity);
      canvas.drawCircle(c, r, paint);
    }

    final w = size.width;
    final h = size.height;

    // Three soft floating dots that breathe in/out at offset phases.
    final p1 = (math.sin(t * 2 * math.pi) + 1) / 2;
    final p2 = (math.sin(t * 2 * math.pi + 2) + 1) / 2;
    final p3 = (math.sin(t * 2 * math.pi + 4) + 1) / 2;

    dot(Offset(w * 0.86, h * 0.18), 2.4, 0.35 + 0.35 * p1);
    dot(Offset(w * 0.10, h * 0.62), 1.8, 0.25 + 0.30 * p2);
    dot(Offset(w * 0.55, h * 0.82), 2.0, 0.20 + 0.30 * p3);
  }

  @override
  bool shouldRepaint(covariant _SparklePainter oldDelegate) => oldDelegate.t != t;
}

// ─── Reward chip (subtitle pill) ──────────────────────────────────────────

class _RewardChip extends StatelessWidget {
  final String text;
  const _RewardChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: AppColors.main.withValues(alpha: 0.25),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_rounded,
              size: 11.sp, color: AppColors.main),
          SizedBox(width: 4.w),
          Flexible(
            child: Text(
              text,
              style: AppTextStyles.getText3(context).copyWith(
                color: AppColors.mainDark,
                fontWeight: FontWeight.w700,
                fontSize: 10.sp,
                letterSpacing: 0.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Primary CTA pill ─────────────────────────────────────────────────────

class _PrimaryCta extends StatelessWidget {
  final String label;
  final bool isRtl;
  final VoidCallback onTap;

  const _PrimaryCta({
    required this.label,
    required this.isRtl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Direction-aware chevron, with a forced LTR Directionality wrap on
    // the Icon so Flutter doesn't auto-mirror `arrow_back_ios_new` (its
    // IconData has matchTextDirection=true, which would flip it back to a
    // right-pointing chevron in our RTL parent).
    final icon = isRtl
        ? Icons.arrow_back_ios_new_rounded
        : Icons.arrow_forward_ios_rounded;

    final radius = BorderRadius.circular(16.r);

    return DecoratedBox(
      // External shadow — must live outside Material to render as a
      // proper rounded glow (Ink/Material can clip box shadows to their
      // own rect, producing visible square corners).
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: AppColors.main.withValues(alpha: 0.30),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.main, AppColors.mainDark],
            ),
          ),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 13.h, horizontal: 16.w),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.max,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.getText2(context).copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Container(
                    width: 22.w,
                    height: 22.w,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: Icon(icon, color: Colors.white, size: 11.sp),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Reward badge (hero coin) ─────────────────────────────────────────────

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
      width: 70.w,
      height: 70.w,
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
                width: 70.w,
                height: 70.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.main.withValues(alpha: 0.22 + 0.10 * t),
                      AppColors.main.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
              // Soft white inner ring (glass edge)
              Container(
                width: 58.w,
                height: 58.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.45),
                ),
              ),
              // Coin disk
              Container(
                width: 52.w,
                height: 52.w,
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
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.mainDark.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Row(
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
              ),
              // Sparkle accent (top-right)
              Positioned(
                top: -2.h,
                right: 0,
                child: Transform.rotate(
                  angle: math.pi / 6 * t,
                  child: Icon(
                    Icons.star_rounded,
                    color: Colors.amber.shade400,
                    size: 16.sp,
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
