import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/models/voucher_model.dart';
import 'package:intl/intl.dart' show DateFormat;

/// Ticket-shaped voucher card with a perforated stub on the trailing
/// edge, glass orb backdrop, and a status-tinted accent rail.
///
/// Visual language matches the broader loyalty surfaces (`EarnPointsBanner`,
/// `CompleteProfileBanner`): cloudy orbs + real BackdropFilter blur + a
/// translucent glass plane carrying the content.
class VoucherCard extends StatelessWidget {
  final VoucherModel voucher;
  final VoidCallback onTap;
  final int index;

  const VoucherCard({
    super.key,
    required this.voucher,
    required this.onTap,
    this.index = 0,
  });

  Color get _statusColor {
    if (voucher.isActive) return AppColors.main;
    if (voucher.isUsed) return const Color(0xFF4CAF50);
    return Colors.grey;
  }

  IconData get _statusIcon {
    if (voucher.isActive) return Icons.confirmation_number_rounded;
    if (voucher.isUsed) return Icons.check_circle_rounded;
    return Icons.timer_off_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    final color = _statusColor;
    final isMuted = !voucher.isActive;

    final expiresText = _formatExpiryText(context, l);
    final progress = _activeProgress();

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 460 + (index * 70)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 22 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            height: 110.h,
            child: CustomPaint(
              painter: _TicketShadowPainter(
                color: color,
                isRtl: isRtl,
                stubOffset: 78.w,
                notchRadius: 9.r,
                borderRadius: 18.r,
                muted: isMuted,
              ),
              child: ClipPath(
                clipper: _TicketClipper(
                  isRtl: isRtl,
                  stubOffset: 78.w,
                  notchRadius: 9.r,
                  borderRadius: 18.r,
                ),
                child: Stack(
                  children: [
                    // Cloudy painted backdrop (active gets vivid orbs;
                    // muted states get a desaturated gray version).
                    Positioned.fill(
                      child: _TicketBackdrop(color: color, muted: isMuted),
                    ),
                    // Real glass blur of the orbs.
                    Positioned.fill(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                        child: const SizedBox.shrink(),
                      ),
                    ),
                    // Tinted glass plane.
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withValues(alpha: 0.78),
                            color.withValues(alpha: isMuted ? 0.04 : 0.06),
                          ],
                        ),
                      ),
                    ),

                    // Status accent rail (leading edge).
                    PositionedDirectional(
                      start: 0,
                      top: 14.h,
                      bottom: 14.h,
                      child: Container(
                        width: 4.w,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              color,
                              Color.lerp(color, Colors.white, 0.35) ?? color,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                      ),
                    ),

                    // Perforated dashed line down the stub seam.
                    PositionedDirectional(
                      end: 78.w,
                      top: 14.h,
                      bottom: 14.h,
                      child: const _DashedVerticalLine(),
                    ),

                    // Content row
                    Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(
                          14.w, 12.h, 78.w + 12.w, 12.h),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _StatusMedallion(color: color, icon: _statusIcon),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  voucher.getLocalizedTitle(locale),
                                  style: AppTextStyles.getText1(context)
                                      .copyWith(
                                    color: AppColors.mainDark,
                                    fontWeight: FontWeight.w800,
                                    height: 1.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 6.h),
                                _CodeChip(code: voucher.code, color: color),
                                SizedBox(height: 6.h),
                                if (voucher.isActive && progress != null)
                                  _CountdownBar(
                                    progress: progress,
                                    text: expiresText,
                                    color: color,
                                  )
                                else
                                  Row(
                                    children: [
                                      Icon(Icons.access_time_rounded,
                                          size: 11.sp,
                                          color: Colors.grey[400]),
                                      SizedBox(width: 4.w),
                                      Flexible(
                                        child: Text(
                                          expiresText,
                                          style: AppTextStyles.getText3(context)
                                              .copyWith(
                                            color: Colors.grey[600],
                                            fontWeight: FontWeight.w500,
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
                        ],
                      ),
                    ),

                    // Stub: vertical, label + arrow medallion
                    PositionedDirectional(
                      end: 0,
                      top: 0,
                      bottom: 0,
                      width: 78.w,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8.w),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _StubBadge(
                                color: color, label: _stubLabel(l)),
                            SizedBox(height: 8.h),
                            Container(
                              width: 28.w,
                              height: 28.w,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [color, AppColors.mainDark],
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.30),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Directionality(
                                textDirection: TextDirection.ltr,
                                child: Icon(
                                  isRtl
                                      ? Icons.arrow_back_ios_new_rounded
                                      : Icons.arrow_forward_ios_rounded,
                                  size: 11.sp,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // "USED" / "EXPIRED" diagonal stamp for muted vouchers.
                    if (voucher.isUsed || voucher.isExpired)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Center(
                            child: Transform.rotate(
                              angle: -0.18,
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 10.w, vertical: 3.h),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: color.withValues(alpha: 0.55),
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(4.r),
                                ),
                                child: Text(
                                  voucher.isUsed ? l.used : l.expired,
                                  style: TextStyle(
                                    color: color.withValues(alpha: 0.65),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14.sp,
                                    letterSpacing: 2.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _stubLabel(AppLocalizations l) {
    if (voucher.isActive) return l.active;
    if (voucher.isUsed) return l.used;
    return l.expired;
  }

  String _formatExpiryText(BuildContext context, AppLocalizations l) {
    try {
      final expires = DateTime.parse(voucher.expiresAt).toLocal();
      final diff = expires.difference(DateTime.now());
      if (voucher.isActive && diff.isNegative) return l.voucherExpired;
      if (voucher.isActive) return l.daysLeft(diff.inDays, diff.inHours % 24);
      return DateFormat('dd/MM/yyyy').format(expires);
    } catch (_) {
      return '—';
    }
  }

  /// 0..1 — share of validity used. Null when not active or unparseable.
  double? _activeProgress() {
    if (!voucher.isActive) return null;
    try {
      final expires = DateTime.parse(voucher.expiresAt).toLocal();
      final redeemed = DateTime.parse(voucher.redeemedAt).toLocal();
      final total = expires.difference(redeemed).inSeconds;
      if (total <= 0) return 1.0;
      final passed = DateTime.now().difference(redeemed).inSeconds;
      return (passed / total).clamp(0.0, 1.0);
    } catch (_) {
      return null;
    }
  }
}

// ─── Ticket clipper ──────────────────────────────────────────────────────

class _TicketClipper extends CustomClipper<Path> {
  final bool isRtl;
  final double stubOffset; // distance from the trailing edge to the notch
  final double notchRadius;
  final double borderRadius;

  _TicketClipper({
    required this.isRtl,
    required this.stubOffset,
    required this.notchRadius,
    required this.borderRadius,
  });

  @override
  Path getClip(Size size) {
    final r = borderRadius;
    final n = notchRadius;
    final notchX = isRtl ? stubOffset : size.width - stubOffset;

    final path = Path()
      ..moveTo(r, 0)
      ..lineTo(notchX - n, 0)
      ..arcToPoint(Offset(notchX + n, 0),
          radius: Radius.circular(n), clockwise: false)
      ..lineTo(size.width - r, 0)
      ..arcToPoint(Offset(size.width, r), radius: Radius.circular(r))
      ..lineTo(size.width, size.height - r)
      ..arcToPoint(Offset(size.width - r, size.height),
          radius: Radius.circular(r))
      ..lineTo(notchX + n, size.height)
      ..arcToPoint(Offset(notchX - n, size.height),
          radius: Radius.circular(n), clockwise: false)
      ..lineTo(r, size.height)
      ..arcToPoint(Offset(0, size.height - r), radius: Radius.circular(r))
      ..lineTo(0, r)
      ..arcToPoint(Offset(r, 0), radius: Radius.circular(r))
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant _TicketClipper oldClipper) =>
      oldClipper.isRtl != isRtl ||
      oldClipper.stubOffset != stubOffset ||
      oldClipper.notchRadius != notchRadius ||
      oldClipper.borderRadius != borderRadius;
}

/// Paints a soft drop shadow that follows the ticket's clipped silhouette.
/// Drawn behind the clipped child so the shadow doesn't get sliced off.
class _TicketShadowPainter extends CustomPainter {
  final Color color;
  final bool isRtl;
  final double stubOffset;
  final double notchRadius;
  final double borderRadius;
  final bool muted;

  _TicketShadowPainter({
    required this.color,
    required this.isRtl,
    required this.stubOffset,
    required this.notchRadius,
    required this.borderRadius,
    required this.muted,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final clipper = _TicketClipper(
      isRtl: isRtl,
      stubOffset: stubOffset,
      notchRadius: notchRadius,
      borderRadius: borderRadius,
    );
    final path = clipper.getClip(size);
    final shadowPaint = Paint()
      ..color = (muted ? Colors.black : color)
          .withValues(alpha: muted ? 0.06 : 0.16)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.save();
    canvas.translate(0, 4);
    canvas.drawPath(path, shadowPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TicketShadowPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.muted != muted ||
      oldDelegate.isRtl != isRtl;
}

// ─── Cloudy backdrop ─────────────────────────────────────────────────────

class _TicketBackdrop extends StatelessWidget {
  final Color color;
  final bool muted;
  const _TicketBackdrop({required this.color, required this.muted});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: Colors.white),
      child: CustomPaint(
        painter: _TicketOrbsPainter(color: color, muted: muted),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _TicketOrbsPainter extends CustomPainter {
  final Color color;
  final bool muted;
  _TicketOrbsPainter({required this.color, required this.muted});

  @override
  void paint(Canvas canvas, Size size) {
    void orb(Offset center, double radius, Color c) {
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [c, c.withValues(alpha: 0.0)],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, paint);
    }

    final base = muted ? Colors.grey : color;
    final accent = muted ? Colors.grey.shade400 : AppColors.background4;

    orb(
      Offset(size.width * 0.10, size.height * 0.4),
      size.width * 0.30,
      base.withValues(alpha: muted ? 0.10 : 0.30),
    );
    orb(
      Offset(size.width * 0.85, size.height * 0.20),
      size.width * 0.25,
      accent.withValues(alpha: 0.7),
    );
    orb(
      Offset(size.width * 0.55, size.height * 1.05),
      size.width * 0.30,
      base.withValues(alpha: muted ? 0.05 : 0.18),
    );
  }

  @override
  bool shouldRepaint(covariant _TicketOrbsPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.muted != muted;
}

// ─── Status medallion ────────────────────────────────────────────────────

class _StatusMedallion extends StatelessWidget {
  final Color color;
  final IconData icon;
  const _StatusMedallion({required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44.w,
      height: 44.w,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.18),
            color.withValues(alpha: 0.06),
          ],
        ),
        border: Border.all(
          color: color.withValues(alpha: 0.30),
          width: 1,
        ),
      ),
      child: Icon(icon, color: color, size: 20.sp),
    );
  }
}

// ─── Code chip ───────────────────────────────────────────────────────────

class _CodeChip extends StatelessWidget {
  final String code;
  final Color color;
  const _CodeChip({required this.code, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
          width: 0.7,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.qr_code_2_rounded, size: 11.sp, color: color),
          SizedBox(width: 4.w),
          Text(
            code,
            style: TextStyle(
              fontSize: 10.5.sp,
              color: color,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Stub badge (vertical "ACTIVE" label) ────────────────────────────────

class _StubBadge extends StatelessWidget {
  final Color color;
  final String label;
  const _StubBadge({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.30), width: 0.7),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 8.5.sp,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

// ─── Countdown bar ───────────────────────────────────────────────────────

class _CountdownBar extends StatelessWidget {
  final double progress; // share consumed
  final String text;
  final Color color;

  const _CountdownBar({
    required this.progress,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = (1 - progress).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(Icons.hourglass_bottom_rounded,
                size: 11.sp, color: color),
            SizedBox(width: 4.w),
            Flexible(
              child: Text(
                text,
                style: AppTextStyles.getText3(context).copyWith(
                  color: AppColors.mainDark.withValues(alpha: 0.75),
                  fontWeight: FontWeight.w700,
                  fontSize: 9.5.sp,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        SizedBox(height: 4.h),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: remaining,
            backgroundColor: color.withValues(alpha: 0.10),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 3.h,
          ),
        ),
      ],
    );
  }
}

// ─── Dashed vertical line (perforation) ──────────────────────────────────

class _DashedVerticalLine extends StatelessWidget {
  const _DashedVerticalLine();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 1.5,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const dashHeight = 4.0;
          const dashSpace = 3.0;
          final count =
              (constraints.maxHeight / (dashHeight + dashSpace)).floor();
          return Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              count,
              (_) => SizedBox(
                width: 1.5,
                height: dashHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.grayMain.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
