import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/models/voucher_model.dart';
import 'package:intl/intl.dart' show DateFormat;

/// Detail page for a single voucher.
///
/// The hero is a true two-section "ticket" with a horizontal perforated
/// divider (notches on the sides + dashed line across). The top section
/// carries the offer identity; the bottom carries the QR code + the
/// tappable code. Below the hero sit glass info rows and a how-to-use
/// strip — all in the same loyalty design system.
class VoucherDetailPage extends StatefulWidget {
  final VoucherModel voucher;

  const VoucherDetailPage({super.key, required this.voucher});

  @override
  State<VoucherDetailPage> createState() => _VoucherDetailPageState();
}

class _VoucherDetailPageState extends State<VoucherDetailPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _heroFade;
  late Animation<Offset> _heroSlide;
  late Animation<double> _contentFade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );
    _heroFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
    );
    _heroSlide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.65, curve: Curves.easeOutCubic),
    ));
    _contentFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.45, 1.0, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _statusColor {
    if (widget.voucher.isActive) return AppColors.main;
    if (widget.voucher.isUsed) return const Color(0xFF4CAF50);
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;

    final expiresFormatted = _formatExpires();
    final color = _statusColor;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        extendBodyBehindAppBar: false,
        appBar: AppBar(
          backgroundColor: const Color(0xFF007E80),
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          iconTheme: const IconThemeData(color: Colors.white),
          title: Text(
            l.voucherDetails,
            style: AppTextStyles.getTitle1(context)
                .copyWith(color: Colors.white),
          ),
        ),
        body: Stack(
          children: [
            // Background gradient that bleeds from the app bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 160.h,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF007E80), Color(0xFF00B4B6)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),

            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding:
                  EdgeInsets.fromLTRB(16.w, 18.h, 16.w, 24.h),
              child: Column(
                children: [
                  // ── HERO TICKET ──
                  FadeTransition(
                    opacity: _heroFade,
                    child: SlideTransition(
                      position: _heroSlide,
                      child: _TicketHero(
                        voucher: widget.voucher,
                        color: color,
                        locale: locale,
                      ),
                    ),
                  ),

                  SizedBox(height: 16.h),

                  // ── DETAILS ──
                  FadeTransition(
                    opacity: _contentFade,
                    child: _GlassPanel(
                      child: Column(
                        children: [
                          if (widget.voucher
                              .getLocalizedPartnerName(locale)
                              .isNotEmpty)
                            _InfoRow(
                              icon: Icons.store_rounded,
                              label: l.partner,
                              value: widget.voucher
                                  .getLocalizedPartnerName(locale),
                              color: AppColors.main,
                            ),
                          if (widget.voucher
                              .getLocalizedPartnerAddress(locale)
                              .isNotEmpty)
                            _InfoRow(
                              icon: Icons.location_on_rounded,
                              label: l.address,
                              value: widget.voucher
                                  .getLocalizedPartnerAddress(locale),
                              color: const Color(0xFF4CAF50),
                            ),
                          _InfoRow(
                            icon: Icons.calendar_today_rounded,
                            label: l.expiresAt,
                            value: expiresFormatted,
                            color: const Color(0xFFFF9800),
                          ),
                          if (widget.voucher.isUsed &&
                              widget.voucher.usedAt != null)
                            _InfoRow(
                              icon: Icons.task_alt_rounded,
                              label: l.voucherUsedAt,
                              value: _formatUsedAt(),
                              color: const Color(0xFF4CAF50),
                            ),
                          if (widget.voucher.discountValue != null)
                            _InfoRow(
                              icon: Icons.discount_rounded,
                              label: l.discount,
                              value: widget.voucher.discountType ==
                                      'percentage'
                                  ? '${widget.voucher.discountValue!.toInt()}%'
                                  : '${widget.voucher.discountValue!.toInt()} ${l.currency}',
                              color: const Color(0xFFE91E63),
                              isLast: true,
                            ),
                        ],
                      ),
                    ),
                  ),

                  if (widget.voucher.isActive) ...[
                    SizedBox(height: 14.h),
                    FadeTransition(
                      opacity: _contentFade,
                      child: _HowToUseCard(),
                    ),
                  ],

                  if (widget.voucher.isActive &&
                      widget.voucher.offerCategory ==
                          'doctor_promotion') ...[
                    SizedBox(height: 12.h),
                    FadeTransition(
                      opacity: _contentFade,
                      child: _DoctorPromotionNote(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatExpires() {
    try {
      return DateFormat('dd/MM/yyyy HH:mm')
          .format(DateTime.parse(widget.voucher.expiresAt).toLocal());
    } catch (_) {
      return '—';
    }
  }

  String _formatUsedAt() {
    final raw = widget.voucher.usedAt;
    if (raw == null) return '—';
    try {
      return DateFormat('dd/MM/yyyy HH:mm')
          .format(DateTime.parse(raw).toLocal());
    } catch (_) {
      return '—';
    }
  }
}

// ─── Hero ticket ─────────────────────────────────────────────────────────

class _TicketHero extends StatelessWidget {
  final VoucherModel voucher;
  final Color color;
  final String locale;

  const _TicketHero({
    required this.voucher,
    required this.color,
    required this.locale,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final isActive = voucher.isActive;

    // Two-section layout: top (offer identity) + bottom (QR + code).
    // The middle is a perforated divider produced by ClipPath cutouts.
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.18),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: AppColors.mainDark.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipPath(
        clipper: _HeroTicketClipper(
          notchY: 200.h, // perforation Y from top of ticket
          notchRadius: 12.r,
          borderRadius: 24.r,
        ),
        child: Stack(
          children: [
            // Cloudy painted backdrop
            const Positioned.fill(child: _HeroBackdrop()),
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: const SizedBox.shrink(),
              ),
            ),
            // Tinted glass plane + content. Combined into one
            // full-width Container so the Stack sizes correctly and the
            // Column's centering aligns with the ticket — not with the
            // intrinsic width of its widest child.
            SizedBox(
              width: double.infinity,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.92),
                      color.withValues(alpha: 0.06),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.65),
                    width: 1.2,
                  ),
                ),
                padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 20.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                  // Status pill
                  _StatusPill(voucher: voucher, color: color),
                  SizedBox(height: 14.h),

                  Text(
                    voucher.getLocalizedTitle(locale),
                    style: AppTextStyles.getTitle1(context).copyWith(
                      color: AppColors.mainDark,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  if (voucher.discountValue != null) ...[
                    SizedBox(height: 10.h),
                    _DiscountChip(
                      value: voucher.discountType == 'percentage'
                          ? '${voucher.discountValue!.toInt()}%'
                          : '${voucher.discountValue!.toInt()} ${l.currency}',
                      color: color,
                    ),
                  ],

                  // Spacer that pushes the QR section to start at ~ notchY.
                  SizedBox(height: 36.h),

                  // ── Below the perforation ──
                  if (isActive) ...[
                    SizedBox(height: 6.h),
                    _QrCard(code: voucher.code),
                    SizedBox(height: 14.h),
                    _CodeRow(code: voucher.code),
                    SizedBox(height: 6.h),
                    Text(
                      l.tapToCopy,
                      style: AppTextStyles.getText3(context).copyWith(
                        color: AppColors.mainDark.withValues(alpha: 0.55),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ] else ...[
                    SizedBox(height: 6.h),
                    _MutedNotice(voucher: voucher),
                  ],
                  ],
                ),
              ),
            ),

            // Dashed line across the perforation seam
            Positioned(
              left: 18.w,
              right: 18.w,
              top: 200.h - 0.5,
              child: const _DashedHorizontalLine(),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroTicketClipper extends CustomClipper<Path> {
  final double notchY;
  final double notchRadius;
  final double borderRadius;

  _HeroTicketClipper({
    required this.notchY,
    required this.notchRadius,
    required this.borderRadius,
  });

  @override
  Path getClip(Size size) {
    final r = borderRadius;
    final n = notchRadius;
    final y = notchY;

    final path = Path()
      ..moveTo(r, 0)
      ..lineTo(size.width - r, 0)
      ..arcToPoint(Offset(size.width, r), radius: Radius.circular(r))
      // Right edge down to notch
      ..lineTo(size.width, y - n)
      ..arcToPoint(Offset(size.width, y + n),
          radius: Radius.circular(n), clockwise: false)
      ..lineTo(size.width, size.height - r)
      ..arcToPoint(Offset(size.width - r, size.height),
          radius: Radius.circular(r))
      ..lineTo(r, size.height)
      ..arcToPoint(Offset(0, size.height - r), radius: Radius.circular(r))
      // Left edge up to notch
      ..lineTo(0, y + n)
      ..arcToPoint(Offset(0, y - n),
          radius: Radius.circular(n), clockwise: false)
      ..lineTo(0, r)
      ..arcToPoint(Offset(r, 0), radius: Radius.circular(r))
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant _HeroTicketClipper oldClipper) =>
      oldClipper.notchY != notchY ||
      oldClipper.notchRadius != notchRadius ||
      oldClipper.borderRadius != borderRadius;
}

class _HeroBackdrop extends StatelessWidget {
  const _HeroBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: Colors.white),
      child: CustomPaint(
        painter: _HeroOrbsPainter(),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _HeroOrbsPainter extends CustomPainter {
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
      Offset(size.width * 0.15, size.height * 0.12),
      size.width * 0.55,
      AppColors.main.withValues(alpha: 0.30),
    );
    orb(
      Offset(size.width * 0.85, size.height * 0.10),
      size.width * 0.45,
      AppColors.background4,
    );
    orb(
      Offset(size.width * 0.50, size.height * 0.95),
      size.width * 0.65,
      AppColors.mainDark.withValues(alpha: 0.18),
    );
    orb(
      Offset(size.width * 0.92, size.height * 0.82),
      size.width * 0.30,
      AppColors.yellow.withValues(alpha: 0.10),
    );
  }

  @override
  bool shouldRepaint(covariant _HeroOrbsPainter oldDelegate) => false;
}

// ─── Status pill ─────────────────────────────────────────────────────────

class _StatusPill extends StatelessWidget {
  final VoucherModel voucher;
  final Color color;
  const _StatusPill({required this.voucher, required this.color});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    String label;
    IconData icon;
    if (voucher.isActive) {
      label = l.active;
      icon = Icons.bolt_rounded;
    } else if (voucher.isUsed) {
      label = l.used;
      icon = Icons.task_alt_rounded;
    } else {
      label = l.expired;
      icon = Icons.cancel_rounded;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: color.withValues(alpha: 0.30),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14.sp, color: color),
          SizedBox(width: 6.w),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Discount chip ───────────────────────────────────────────────────────

class _DiscountChip extends StatelessWidget {
  final String value;
  final Color color;
  const _DiscountChip({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, AppColors.mainDark],
        ),
        borderRadius: BorderRadius.circular(99),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.30),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_offer_rounded, size: 13.sp, color: Colors.white),
          SizedBox(width: 6.w),
          Text(
            value,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── QR card ─────────────────────────────────────────────────────────────

class _QrCard extends StatelessWidget {
  final String code;
  const _QrCard({required this.code});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(
          color: AppColors.main.withValues(alpha: 0.15),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.main.withValues(alpha: 0.10),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: QrImageView(
        data: code,
        version: QrVersions.auto,
        size: 170.w,
        gapless: true,
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: AppColors.mainDark,
        ),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: AppColors.mainDark,
        ),
      ),
    );
  }
}

// ─── Tappable code row ───────────────────────────────────────────────────

class _CodeRow extends StatelessWidget {
  final String code;
  const _CodeRow({required this.code});

  void _copy(BuildContext context) {
    HapticFeedback.selectionClick();
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.codeCopied),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.r)),
        backgroundColor: AppColors.main,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _copy(context),
      borderRadius: BorderRadius.circular(14.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 14.h),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.main.withValues(alpha: 0.10),
              AppColors.background4,
            ],
          ),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: AppColors.main.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              code,
              style: TextStyle(
                fontSize: 22.sp,
                fontWeight: FontWeight.w900,
                color: AppColors.mainDark,
                letterSpacing: 3,
              ),
            ),
            SizedBox(width: 12.w),
            Container(
              width: 26.w,
              height: 26.w,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.main,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.copy_rounded,
                  size: 13.sp, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Muted notice (used / expired vouchers don't need a QR) ──────────────

class _MutedNotice extends StatelessWidget {
  final VoucherModel voucher;
  const _MutedNotice({required this.voucher});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final isUsed = voucher.isUsed;
    final color =
        isUsed ? const Color(0xFF4CAF50) : Colors.grey.shade500;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 16.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isUsed ? Icons.task_alt_rounded : Icons.timer_off_rounded,
            color: color,
            size: 18.sp,
          ),
          SizedBox(width: 8.w),
          Text(
            isUsed ? l.used : l.expired,
            style: AppTextStyles.getText1(context).copyWith(
              color: color,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Glass panel + info row ──────────────────────────────────────────────

class _GlassPanel extends StatelessWidget {
  final Widget child;
  const _GlassPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18.r),
      child: Stack(
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: const SizedBox.shrink(),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(18.r),
              border: Border.all(
                color: AppColors.main.withValues(alpha: 0.10),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 4.h),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isLast;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34.w,
            height: 34.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: 0.20),
                  color.withValues(alpha: 0.06),
                ],
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withValues(alpha: 0.25),
                width: 0.8,
              ),
            ),
            child: Icon(icon, size: 15.sp, color: color),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10.5.sp,
                    color: AppColors.grayMain,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  value,
                  style: AppTextStyles.getText2(context).copyWith(
                    color: AppColors.mainDark,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
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

// ─── How-to-use card ─────────────────────────────────────────────────────

class _HowToUseCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.main.withValues(alpha: 0.10),
            AppColors.background4,
          ],
        ),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(
          color: AppColors.main.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30.w,
                height: 30.w,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.main, AppColors.mainDark],
                  ),
                ),
                child: Icon(Icons.lightbulb_outline_rounded,
                    size: 15.sp, color: Colors.white),
              ),
              SizedBox(width: 10.w),
              Text(
                l.howToUse,
                style: AppTextStyles.getText1(context).copyWith(
                  color: AppColors.mainDark,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Text(
            l.voucherInstructions,
            style: AppTextStyles.getText2(context).copyWith(
              color: AppColors.mainDark.withValues(alpha: 0.78),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Doctor-promotion note ───────────────────────────────────────────────

class _DoctorPromotionNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: const Color(0xFFFF9800).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: const Color(0xFFFF9800).withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.payments_rounded,
              size: 16.sp, color: const Color(0xFFE07000)),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              l.promotionShowCodeAtPayment,
              style: AppTextStyles.getText2(context).copyWith(
                color: const Color(0xFFB85400),
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Dashed horizontal line ──────────────────────────────────────────────

class _DashedHorizontalLine extends StatelessWidget {
  const _DashedHorizontalLine();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 1.5,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const dashWidth = 5.0;
          const dashSpace = 4.0;
          final count =
              (constraints.maxWidth / (dashWidth + dashSpace)).floor();
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              count,
              (_) => SizedBox(
                width: dashWidth,
                height: 1.5,
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
