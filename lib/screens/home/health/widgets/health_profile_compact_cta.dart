import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/screens/home/health/wizard/health_profile_wizard_page.dart';
import 'package:docsera/services/supabase/repositories/health_profile_repository.dart';

/// Compact horizontal CTA card for surfacing the "complete your health
/// profile" prompt outside the Health page.
///
/// Self-loads completion state from `users.health_profile_completed_at`;
/// renders nothing when the user has already completed the wizard or
/// when no auth session exists.
///
/// Visual language matches the larger `CompleteProfileBanner`:
/// cloudy glass surface, real BackdropFilter blur, hairline gradient
/// border, floating reward badge and a directional pill CTA.
class HealthProfileCompactCta extends StatefulWidget {
  const HealthProfileCompactCta({super.key});

  @override
  State<HealthProfileCompactCta> createState() =>
      _HealthProfileCompactCtaState();
}

class _HealthProfileCompactCtaState extends State<HealthProfileCompactCta>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  bool _show = false;

  late final AnimationController _entry;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _entry = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );
    _fade = CurvedAnimation(parent: _entry, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.10),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entry, curve: Curves.easeOutCubic));
    _scale = Tween<double>(begin: 0.95, end: 1.0)
        .animate(CurvedAnimation(parent: _entry, curve: Curves.easeOutCubic));
    _check();
  }

  @override
  void dispose() {
    _entry.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() { _loading = false; _show = false; });
      return;
    }
    try {
      final res = await client
          .from('users')
          .select('health_profile_completed_at')
          .eq('id', user.id)
          .maybeSingle();
      final raw = res?['health_profile_completed_at'] as String?;
      if (!mounted) return;
      setState(() {
        _loading = false;
        _show = raw == null;
      });
      // Glide in once the data confirms the card should show. Defer to a
      // post-frame callback so the layout has the final size before the
      // slide/scale begins.
      if (_show) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _entry.forward();
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() { _loading = false; _show = false; });
    }
  }

  void _open() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HealthProfileWizardPage(
          repo: HealthProfileRepository(),
          userId: user.id,
        ),
      ),
    ).then((_) => _check());
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || !_show) return const SizedBox.shrink();
    final t = AppLocalizations.of(context)!;
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: ScaleTransition(
          scale: _scale,
          child: _buildCard(context, t, isRtl),
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, AppLocalizations t, bool isRtl) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18.r),
        boxShadow: [
          BoxShadow(
            color: AppColors.main.withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18.r),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _open,
            borderRadius: BorderRadius.circular(18.r),
            child: Stack(
              children: [
                // Cloudy painted backdrop (mini orbs).
                const Positioned.fill(child: _MiniCloudyBackdrop()),

                // Real-blur glass plane.
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                    child: const SizedBox.shrink(),
                  ),
                ),

                // Tinted glass + content
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.72),
                        AppColors.background4.withValues(alpha: 0.55),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.65),
                      width: 1,
                    ),
                  ),
                  padding: EdgeInsets.fromLTRB(12.w, 11.h, 10.w, 11.h),
                  child: Row(
                    children: [
                      const _MiniBadge(),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              t.healthProfile_points_inline_title,
                              style: AppTextStyles.getText1(context).copyWith(
                                color: AppColors.mainDark,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.1,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 3.h),
                            Row(
                              children: [
                                Icon(Icons.auto_awesome_rounded,
                                    size: 10.sp, color: AppColors.main),
                                SizedBox(width: 4.w),
                                Flexible(
                                  child: Text(
                                    t.healthProfile_points_inline_subtitle,
                                    style: AppTextStyles.getText3(context)
                                        .copyWith(
                                      color: AppColors.mainDark
                                          .withValues(alpha: 0.75),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 9.5.sp,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 8.w),
                      _CtaPill(
                        label: t.healthProfile_points_inline_cta,
                        isRtl: isRtl,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Mini cloudy backdrop ────────────────────────────────────────────────

class _MiniCloudyBackdrop extends StatelessWidget {
  const _MiniCloudyBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: Colors.white),
      child: CustomPaint(
        painter: _MiniOrbsPainter(),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _MiniOrbsPainter extends CustomPainter {
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
      Offset(size.width * 0.12, size.height * 0.40),
      size.width * 0.32,
      AppColors.main.withValues(alpha: 0.32),
    );
    orb(
      Offset(size.width * 0.88, size.height * 0.30),
      size.width * 0.28,
      AppColors.background4,
    );
    orb(
      Offset(size.width * 0.55, size.height * 1.10),
      size.width * 0.42,
      AppColors.mainDark.withValues(alpha: 0.20),
    );
  }

  @override
  bool shouldRepaint(covariant _MiniOrbsPainter oldDelegate) => false;
}

// ─── CTA pill with directional chevron ───────────────────────────────────

class _CtaPill extends StatelessWidget {
  final String label;
  final bool isRtl;

  const _CtaPill({required this.label, required this.isRtl});

  @override
  Widget build(BuildContext context) {
    // Direction-aware chevron, with a forced LTR Directionality wrap on
    // the Icon so Flutter doesn't auto-mirror `arrow_back_ios_new` (its
    // IconData has matchTextDirection=true, which would flip it back to
    // a right-pointing chevron in our RTL parent).
    final icon = isRtl
        ? Icons.arrow_back_ios_new_rounded
        : Icons.arrow_forward_ios_rounded;

    return Container(
      padding: EdgeInsets.fromLTRB(11.w, 6.h, 8.w, 6.h),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.main, AppColors.mainDark],
        ),
        borderRadius: BorderRadius.circular(99),
        boxShadow: [
          BoxShadow(
            color: AppColors.main.withValues(alpha: 0.30),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTextStyles.getText3(context).copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
          SizedBox(width: 5.w),
          Container(
            width: 16.w,
            height: 16.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.20),
              shape: BoxShape.circle,
            ),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Icon(icon, color: Colors.white, size: 8.sp),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Mini reward badge ───────────────────────────────────────────────────

class _MiniBadge extends StatefulWidget {
  const _MiniBadge();

  @override
  State<_MiniBadge> createState() => _MiniBadgeState();
}

class _MiniBadgeState extends State<_MiniBadge>
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
      width: 44.w,
      height: 44.w,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (_, __) {
          final t = _pulse.value;
          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Soft halo
              Container(
                width: 44.w,
                height: 44.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.main.withValues(alpha: 0.18 + 0.10 * t),
                      AppColors.main.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
              // Glass ring
              Container(
                width: 38.w,
                height: 38.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.45),
                ),
              ),
              // Coin
              Container(
                width: 34.w,
                height: 34.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.main, AppColors.mainDark],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.55),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.mainDark.withValues(alpha: 0.30),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(top: 2.h),
                      child: Text(
                        '+',
                        style: AppTextStyles.getText3(context).copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          height: 1,
                          fontSize: 8.sp,
                        ),
                      ),
                    ),
                    Text(
                      '15',
                      style: AppTextStyles.getText1(context).copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        height: 1,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
              // Sparkle
              Positioned(
                top: -1.h,
                right: -1.w,
                child: Transform.rotate(
                  angle: math.pi / 6 * t,
                  child: Icon(
                    Icons.star_rounded,
                    size: 11.sp,
                    color: Colors.amber.shade400,
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
