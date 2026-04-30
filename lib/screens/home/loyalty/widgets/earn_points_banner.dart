import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';

/// Slim glass banner shown above the earn/spend stats on the My Points
/// page. Tapping anywhere (or the trailing info button) opens a glassy
/// bottom sheet that explains every way to earn points.
class EarnPointsBanner extends StatelessWidget {
  const EarnPointsBanner({super.key});

  void _openSheet(BuildContext context) {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (_) => const _EarnPointsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14.r),
        boxShadow: [
          BoxShadow(
            color: AppColors.main.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14.r),
        child: Stack(
          children: [
            // Soft painted backdrop with a couple of teal orbs.
            const Positioned.fill(child: _BannerBackdrop()),
            // Real glass blur.
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: const SizedBox.shrink(),
              ),
            ),

            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _openSheet(context),
                child: Container(
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
                      width: 1,
                    ),
                  ),
                  padding:
                      EdgeInsets.symmetric(horizontal: 12.w, vertical: 9.h),
                  child: Row(
                    children: [
                      // Leading sparkly icon
                      Container(
                        width: 28.w,
                        height: 28.w,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [AppColors.main, AppColors.mainDark],
                          ),
                        ),
                        child: Icon(Icons.auto_awesome_rounded,
                            size: 14.sp, color: Colors.white),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              l.earnBannerTitle,
                              style: AppTextStyles.getText2(context).copyWith(
                                color: AppColors.mainDark,
                                fontWeight: FontWeight.w800,
                                height: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              l.earnBannerSubtitle,
                              style: AppTextStyles.getText3(context).copyWith(
                                color: AppColors.mainDark
                                    .withValues(alpha: 0.65),
                                fontSize: 9.5.sp,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 8.w),
                      // Trailing info pill
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 8.w, vertical: 5.h),
                        decoration: BoxDecoration(
                          color: AppColors.main.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                            color: AppColors.main.withValues(alpha: 0.30),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.info_outline_rounded,
                                size: 12.sp, color: AppColors.mainDark),
                            SizedBox(width: 4.w),
                            Icon(Icons.expand_less_rounded,
                                size: 12.sp, color: AppColors.mainDark),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BannerBackdrop extends StatelessWidget {
  const _BannerBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: Colors.white),
      child: CustomPaint(
        painter: _BannerOrbsPainter(),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _BannerOrbsPainter extends CustomPainter {
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
      Offset(size.width * 0.10, size.height * 0.5),
      size.width * 0.30,
      AppColors.main.withValues(alpha: 0.30),
    );
    orb(
      Offset(size.width * 0.90, size.height * 0.4),
      size.width * 0.25,
      AppColors.background4,
    );
  }

  @override
  bool shouldRepaint(covariant _BannerOrbsPainter oldDelegate) => false;
}

// ─── Bottom sheet ─────────────────────────────────────────────────────────

class _EarnPointsSheet extends StatefulWidget {
  const _EarnPointsSheet();

  @override
  State<_EarnPointsSheet> createState() => _EarnPointsSheetState();
}

class _EarnPointsSheetState extends State<_EarnPointsSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entry;

  @override
  void initState() {
    super.initState();
    _entry = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 680),
    )..forward();
  }

  @override
  void dispose() {
    _entry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    final sources = <_EarnSource>[
      _EarnSource(
        icon: Icons.calendar_today_rounded,
        color: const Color(0xFF4CAF50),
        title: l.earnSourceAppointmentName,
        description: l.earnSourceAppointmentDesc,
        points: 5,
        recurring: true,
      ),
      _EarnSource(
        icon: Icons.person_add_alt_1_rounded,
        color: AppColors.main,
        title: l.earnSourceReferralName,
        description: l.earnSourceReferralDesc,
        points: 25,
        recurring: true,
      ),
      _EarnSource(
        icon: Icons.card_giftcard_rounded,
        color: const Color(0xFFFF9800),
        title: l.earnSourceReferredName,
        description: l.earnSourceReferredDesc,
        points: 15,
        recurring: false,
      ),
      _EarnSource(
        icon: Icons.favorite_rounded,
        color: const Color(0xFFE91E63),
        title: l.earnSourceHealthProfileName,
        description: l.earnSourceHealthProfileDesc,
        points: 15,
        recurring: false,
      ),
    ];

    return ClipRRect(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
      child: Stack(
        children: [
          // Painted color cloud behind the glass
          const Positioned.fill(child: _SheetBackdrop()),
          // Real glass blur
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
              child: const SizedBox.shrink(),
            ),
          ),

          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.92),
                  Colors.white.withValues(alpha: 0.86),
                ],
              ),
              border: Border(
                top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.7),
                  width: 1.2,
                ),
              ),
            ),
            padding: EdgeInsets.fromLTRB(
              16.w,
              10.h,
              16.w,
              MediaQuery.of(context).padding.bottom + 18.h,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  width: 44.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                SizedBox(height: 18.h),

                // Header — gradient pill icon + title
                Row(
                  children: [
                    Container(
                      width: 44.w,
                      height: 44.w,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppColors.main, AppColors.mainDark],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.main.withValues(alpha: 0.35),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Icon(Icons.emoji_events_rounded,
                          color: Colors.white, size: 22.sp),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            l.earnPointsTitle,
                            style: AppTextStyles.getTitle2(context).copyWith(
                              color: AppColors.mainDark,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            l.earnSheetSubtitle,
                            style: AppTextStyles.getText3(context).copyWith(
                              color: AppColors.grayMain,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Close button
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: Icon(Icons.close_rounded,
                          size: 18.sp, color: AppColors.grayMain),
                      style: IconButton.styleFrom(
                        backgroundColor:
                            Colors.grey.withValues(alpha: 0.10),
                        padding: EdgeInsets.all(6.r),
                        minimumSize: Size(28.w, 28.w),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 18.h),

                // Source cards (staggered fade/slide-in)
                ...List.generate(sources.length, (i) {
                  final start = (i * 0.12).clamp(0.0, 1.0);
                  final end = (start + 0.55).clamp(0.0, 1.0);
                  final curved = CurvedAnimation(
                    parent: _entry,
                    curve: Interval(start, end, curve: Curves.easeOutCubic),
                  );
                  return Padding(
                    padding: EdgeInsets.only(bottom: 10.h),
                    child: AnimatedBuilder(
                      animation: curved,
                      builder: (_, child) {
                        return Opacity(
                          opacity: curved.value,
                          child: Transform.translate(
                            offset: Offset(0, 14 * (1 - curved.value)),
                            child: child,
                          ),
                        );
                      },
                      child: _SourceCard(source: sources[i]),
                    ),
                  );
                }),

                SizedBox(height: 12.h),

                // Got it CTA
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.main,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(vertical: 13.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                    ),
                    child: Text(
                      l.earnSheetGotIt,
                      style: AppTextStyles.getText2(context).copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
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

// ─── Sheet backdrop (cloudy color paint) ─────────────────────────────────

class _SheetBackdrop extends StatelessWidget {
  const _SheetBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: Colors.white),
      child: CustomPaint(
        painter: _SheetOrbsPainter(),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _SheetOrbsPainter extends CustomPainter {
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
      Offset(size.width * 0.18, size.height * 0.10),
      size.width * 0.50,
      AppColors.main.withValues(alpha: 0.28),
    );
    orb(
      Offset(size.width * 0.92, size.height * 0.20),
      size.width * 0.40,
      AppColors.background4,
    );
    orb(
      Offset(size.width * 0.50, size.height * 0.95),
      size.width * 0.55,
      const Color(0xFFE91E63).withValues(alpha: 0.10),
    );
    orb(
      Offset(size.width * 0.10, size.height * 0.65),
      size.width * 0.35,
      const Color(0xFF4CAF50).withValues(alpha: 0.10),
    );
  }

  @override
  bool shouldRepaint(covariant _SheetOrbsPainter oldDelegate) => false;
}

// ─── Source card ─────────────────────────────────────────────────────────

class _EarnSource {
  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final int points;
  final bool recurring;

  const _EarnSource({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    required this.points,
    required this.recurring,
  });
}

class _SourceCard extends StatelessWidget {
  final _EarnSource source;
  const _SourceCard({required this.source});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = source.color;
    return Container(
      padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 12.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.r),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            c.withValues(alpha: 0.08),
            c.withValues(alpha: 0.02),
          ],
        ),
        border: Border.all(color: c.withValues(alpha: 0.20), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon medallion with subtle inner gloss
          Container(
            width: 42.w,
            height: 42.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [c, Color.lerp(c, Colors.black, 0.18) ?? c],
              ),
              boxShadow: [
                BoxShadow(
                  color: c.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(source.icon, color: Colors.white, size: 18.sp),
          ),
          SizedBox(width: 12.w),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        source.title,
                        style: AppTextStyles.getText1(context).copyWith(
                          color: AppColors.mainDark,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    // Points badge
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 8.w, vertical: 3.h),
                      decoration: BoxDecoration(
                        color: c,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        l.earnPointsBadge(source.points),
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 10.sp,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                Text(
                  source.description,
                  style: AppTextStyles.getText3(context).copyWith(
                    color: AppColors.grayMain,
                    height: 1.35,
                    fontSize: 10.5.sp,
                  ),
                ),
                SizedBox(height: 8.h),
                // Cadence pill
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 7.w, vertical: 3.h),
                      decoration: BoxDecoration(
                        color: c.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color: c.withValues(alpha: 0.25),
                          width: 0.7,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            source.recurring
                                ? Icons.refresh_rounded
                                : Icons.bolt_rounded,
                            size: 10.sp,
                            color: c,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            source.recurring
                                ? l.earnSheetRecurring
                                : l.earnSheetOneTime,
                            style: TextStyle(
                              fontSize: 9.5.sp,
                              fontWeight: FontWeight.w700,
                              color: Color.lerp(c, Colors.black, 0.25),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

