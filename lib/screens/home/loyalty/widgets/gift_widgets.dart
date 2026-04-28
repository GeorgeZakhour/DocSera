import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/models/gift.dart';

/// Opens the [GiftDetailSheet] for [gift] using the same modal config the
/// vouchers page uses (transparent backdrop, dim barrier, scrollable).
void showGiftDetailSheet(BuildContext context, Gift gift) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x66000000),
    builder: (ctx) => GiftDetailSheet(gift: gift),
  );
}

// ─── Gift card ────────────────────────────────────────────────────────────

class GiftCard extends StatelessWidget {
  final Gift gift;
  final int index;
  final VoidCallback onTap;
  /// Outer padding around the card. Defaults to the wallet list's
  /// 16.w / 5.h gutter; pass [EdgeInsets.zero] when the parent already
  /// owns horizontal padding (e.g. doctor profile content column).
  final EdgeInsetsGeometry? padding;

  const GiftCard({
    super.key,
    required this.gift,
    required this.onTap,
    this.index = 0,
    this.padding,
  });

  /// Derives the effective display status client-side.
  /// A claimed gift whose expires_at has passed is treated as expired
  /// even if the DB row hasn't been flipped yet by a background job.
  String get _resolvedStatus {
    if (gift.status == 'claimed' &&
        gift.expiresAt != null &&
        gift.expiresAt!.isBefore(DateTime.now())) {
      return 'expired';
    }
    return gift.status;
  }

  Color get _statusColor {
    switch (_resolvedStatus) {
      case 'used':
        return const Color(0xFF4CAF50);
      case 'expired':
        return Colors.grey;
      default:
        return const Color(0xFFE91E8C);
    }
  }

  IconData get _statusIcon {
    switch (_resolvedStatus) {
      case 'used':
        return Icons.check_circle_rounded;
      case 'expired':
        return Icons.timer_off_rounded;
      default:
        return Icons.card_giftcard_rounded;
    }
  }

  String _statusLabel(AppLocalizations l) {
    switch (_resolvedStatus) {
      case 'used':
        return l.voucherPageGiftStatusUsed;
      case 'expired':
        return l.voucherPageGiftStatusExpired;
      default:
        return l.voucherPageGiftStatusClaimed;
    }
  }

  String _discountText(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    if (gift.discountValue == null) return '';
    if (gift.discountType == 'percentage') {
      return '${gift.discountValue!.toInt()}%';
    }
    return '${gift.discountValue!.toInt()} ${l.currency}';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final color = _statusColor;
    final isMuted = _resolvedStatus != 'claimed';
    final title = locale == 'ar'
        ? (gift.customTitleAr ?? gift.customTitle ?? gift.offerType)
        : (gift.customTitle ?? gift.offerType);
    final sentDate =
        DateFormat('dd/MM/yyyy').format(gift.sentAt.toLocal());
    final discount = _discountText(context);

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
        padding: padding ?? EdgeInsets.symmetric(horizontal: 16.w, vertical: 5.h),
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            decoration: BoxDecoration(
              // Subtle pale rose gradient — one focal point (the discount
              // badge) pops; the card itself stays calm and receipt-like.
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, Color(0xFFFFF1F5)],
              ),
              borderRadius: BorderRadius.circular(18.r),
              border: Border.all(
                color: const Color(0xFFEC4899).withValues(alpha: 0.18),
                width: 0.8,
              ),
              boxShadow: const [
                // Neutral shadow — not pink-tinted so the card stays calm.
                BoxShadow(
                  color: Color(0x0A000000), // black ~4%
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Soft orb backdrop
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18.r),
                    child: CustomPaint(
                      painter:
                          _GiftOrbsPainter(color: color, muted: isMuted),
                    ),
                  ),
                ),
                // Glass blur
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18.r),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: const SizedBox.shrink(),
                    ),
                  ),
                ),
                // Accent rail
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
                          Color.lerp(color, Colors.white, 0.4) ?? color,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                  ),
                ),
                // Content
                Padding(
                  padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 12.h),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _GiftDoctorAvatar(
                        imageUrl: gift.doctorImage,
                        color: color,
                        icon: _statusIcon,
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: AppTextStyles.getText1(context)
                                        .copyWith(
                                      color: AppColors.mainDark,
                                      fontWeight: FontWeight.w800,
                                      height: 1.2,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (discount.isNotEmpty) ...[
                                  SizedBox(width: 8.w),
                                  _GiftDiscountBadge(
                                      value: discount, color: color),
                                ],
                              ],
                            ),
                            SizedBox(height: 5.h),
                            Text(
                              l.voucherPageGiftSentBy(gift.doctorName),
                              style: AppTextStyles.getText3(context).copyWith(
                                color: AppColors.mainDark
                                    .withValues(alpha: 0.65),
                                fontWeight: FontWeight.w600,
                                fontSize: 10.sp,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 3.h),
                            Text(
                              l.voucherPageGiftSentOn(sentDate),
                              style: AppTextStyles.getText3(context).copyWith(
                                color: Colors.grey[500],
                                fontSize: 9.5.sp,
                              ),
                            ),
                            SizedBox(height: 6.h),
                            Row(
                              children: [
                                _GiftStatusPill(
                                  label: _statusLabel(l),
                                  icon: _statusIcon,
                                  color: color,
                                ),
                                SizedBox(width: 8.w),
                                Flexible(
                                  child: _GiftCodeChip(
                                    code: gift.voucherCode,
                                    color: color,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: EdgeInsetsDirectional.only(
                            start: 6.w, top: 2.h),
                        child: Icon(
                          Icons.chevron_right_rounded,
                          size: 18.sp,
                          color: color.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                ),

                // Muted diagonal stamp
                if (isMuted)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18.r),
                        child: Center(
                          child: Transform.rotate(
                            angle: -0.18,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 10.w, vertical: 3.h),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: color.withValues(alpha: 0.45),
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(4.r),
                              ),
                              child: Text(
                                _statusLabel(l),
                                style: TextStyle(
                                  color: color.withValues(alpha: 0.55),
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
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Doctor avatar ────────────────────────────────────────────────────────

class _GiftDoctorAvatar extends StatelessWidget {
  final String? imageUrl;
  final Color color;
  final IconData icon;

  const _GiftDoctorAvatar({
    required this.imageUrl,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final size = 46.w;
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: Image.network(
          imageUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholder(size, color, icon),
        ),
      );
    }
    return _placeholder(size, color, icon);
  }

  Widget _placeholder(double size, Color color, IconData icon) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.20),
            color.withValues(alpha: 0.07),
          ],
        ),
        border: Border.all(color: color.withValues(alpha: 0.30), width: 1),
      ),
      child: Icon(icon, size: 22.sp, color: color),
    );
  }
}

// ─── Gift status pill ─────────────────────────────────────────────────────

class _GiftStatusPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _GiftStatusPill({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 0.7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10.sp, color: color),
          SizedBox(width: 4.w),
          Text(
            label,
            style: TextStyle(
              fontSize: 9.sp,
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

// ─── Gift code chip ───────────────────────────────────────────────────────

class _GiftCodeChip extends StatelessWidget {
  final String code;
  final Color color;

  const _GiftCodeChip({required this.code, required this.color});

  @override
  Widget build(BuildContext context) {
    // Neutral chip — no pink gradient here; let the discount badge be loud.
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6), // light grey, theme-neutral
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.25),
          width: 0.7,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.qr_code_2_rounded,
              size: 10.sp, color: Colors.grey.shade600),
          SizedBox(width: 3.w),
          Flexible(
            child: Text(
              code,
              style: TextStyle(
                fontSize: 9.5.sp,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                fontFamily: 'monospace',
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

// ─── Gift discount badge ──────────────────────────────────────────────────

class _GiftDiscountBadge extends StatelessWidget {
  final String value;
  final Color color;

  const _GiftDiscountBadge({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, AppColors.mainDark],
        ),
        borderRadius: BorderRadius.circular(99),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.28),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        value,
        style: TextStyle(
          fontSize: 10.sp,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

// ─── Gift orbs painter ────────────────────────────────────────────────────

class _GiftOrbsPainter extends CustomPainter {
  final Color color;
  final bool muted;

  _GiftOrbsPainter({required this.color, required this.muted});

  @override
  void paint(Canvas canvas, Size size) {
    void orb(Offset center, double radius, Color c) {
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [c, c.withValues(alpha: 0.0)],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, paint);
    }

    // Kept very faint so the discount badge remains the only pop.
    orb(
      Offset(size.width * 0.08, size.height * 0.5),
      size.width * 0.22,
      color.withValues(alpha: muted ? 0.04 : 0.09),
    );
    orb(
      Offset(size.width * 0.88, size.height * 0.2),
      size.width * 0.20,
      AppColors.background4.withValues(alpha: 0.25),
    );
  }

  @override
  bool shouldRepaint(covariant _GiftOrbsPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.muted != muted;
}

// ─── Gift detail bottom sheet ─────────────────────────────────────────────

class GiftDetailSheet extends StatelessWidget {
  final Gift gift;

  const GiftDetailSheet({super.key, required this.gift});

  Color get _statusColor {
    switch (gift.status) {
      case 'used':
        return const Color(0xFF4CAF50);
      case 'expired':
        return Colors.grey;
      default:
        return const Color(0xFFE91E8C);
    }
  }

  String _statusLabel(AppLocalizations l) {
    switch (gift.status) {
      case 'used':
        return l.voucherPageGiftStatusUsed;
      case 'expired':
        return l.voucherPageGiftStatusExpired;
      default:
        return l.voucherPageGiftStatusClaimed;
    }
  }

  IconData get _statusIcon {
    switch (gift.status) {
      case 'used':
        return Icons.check_circle_rounded;
      case 'expired':
        return Icons.timer_off_rounded;
      default:
        return Icons.card_giftcard_rounded;
    }
  }

  void _copyCode(BuildContext context) {
    HapticFeedback.selectionClick();
    Clipboard.setData(ClipboardData(text: gift.voucherCode));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.personalGiftCopied),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.r)),
        backgroundColor: const Color(0xFFE91E8C),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final color = _statusColor;
    final isActive = gift.status == 'claimed';

    final title = locale == 'ar'
        ? (gift.customTitleAr ?? gift.customTitle ?? gift.offerType)
        : (gift.customTitle ?? gift.offerType);

    final description = locale == 'ar'
        ? (gift.descriptionAr ?? gift.description)
        : (gift.description ?? gift.descriptionAr);

    final expiryText = gift.expiresAt != null
        ? DateFormat('dd/MM/yyyy').format(gift.expiresAt!.toLocal())
        : l.personalGiftNoExpiry;

    String discountText = '';
    if (gift.discountValue != null) {
      discountText = gift.discountType == 'percentage'
          ? '${gift.discountValue!.toInt()}%'
          : '${gift.discountValue!.toInt()} ${l.currency}';
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.55,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return ClipRRect(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
          child: Stack(
            children: [
              // Sheet surface — solid white so content reads cleanly.
              // The backdrop blur at low sigma keeps edges soft without
              // darkening the sheet body (was sigmaX:20 + heavy dim before).
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Container(
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                ),
              ),
              Positioned.fill(
                child: Container(color: Colors.white),
              ),
              // Content
              SingleChildScrollView(
                controller: scrollController,
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Drag handle
                    SizedBox(height: 12.h),
                    Container(
                      width: 40.w,
                      height: 4.h,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    SizedBox(height: 20.h),

                    // Doctor avatar + name
                    _GiftDoctorAvatar(
                      imageUrl: gift.doctorImage,
                      color: color,
                      icon: _statusIcon,
                    ),
                    SizedBox(height: 10.h),
                    Text(
                      l.voucherPageGiftSentBy(gift.doctorName),
                      style: AppTextStyles.getText2(context).copyWith(
                        color: AppColors.mainDark.withValues(alpha: 0.75),
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      l.voucherPageGiftDetailTitle,
                      style: AppTextStyles.getTitle1(context).copyWith(
                        color: AppColors.mainDark,
                        fontWeight: FontWeight.w900,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    SizedBox(height: 14.h),

                    // Status pill
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 14.w, vertical: 7.h),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                            color: color.withValues(alpha: 0.30), width: 0.8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_statusIcon, size: 13.sp, color: color),
                          SizedBox(width: 6.w),
                          Text(
                            _statusLabel(l),
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w800,
                              color: color,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 20.h),

                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Offer title + discount
                          Center(
                            child: Text(
                              title,
                              style: AppTextStyles.getTitle2(context).copyWith(
                                color: AppColors.mainDark,
                                fontWeight: FontWeight.w800,
                                height: 1.3,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          if (discountText.isNotEmpty) ...[
                            SizedBox(height: 10.h),
                            Center(
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 18.w, vertical: 8.h),
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
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.local_offer_rounded,
                                        size: 14.sp, color: Colors.white),
                                    SizedBox(width: 6.w),
                                    Text(
                                      discountText,
                                      style: TextStyle(
                                        fontSize: 15.sp,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],

                          // Doctor's personal message
                          if (gift.message != null &&
                              gift.message!.isNotEmpty) ...[
                            SizedBox(height: 20.h),
                            Text(
                              l.voucherPageGiftDoctorMessageHeading,
                              style: AppTextStyles.getText2(context).copyWith(
                                color: AppColors.mainDark,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 8.h),
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(14.w),
                              decoration: BoxDecoration(
                                // Very subtle tint, nearly white so text
                                // reads at full contrast on the white sheet.
                                color: const Color(0xFFFFF9FB),
                                borderRadius: BorderRadius.circular(14.r),
                                border: const Border(
                                  left: BorderSide(
                                    color: Color(0xFFEC4899),
                                    width: 3,
                                  ),
                                ),
                              ),
                              child: Text(
                                gift.message!,
                                style: AppTextStyles.getText2(context).copyWith(
                                  // Full contrast on white — easy to read.
                                  color: Colors.black87,
                                  height: 1.55,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],

                          // Description
                          if (description != null &&
                              description.isNotEmpty) ...[
                            SizedBox(height: 14.h),
                            Text(
                              description,
                              style: AppTextStyles.getText2(context).copyWith(
                                color: AppColors.mainDark
                                    .withValues(alpha: 0.70),
                                height: 1.5,
                              ),
                            ),
                          ],

                          SizedBox(height: 20.h),

                          // QR + code (active gifts only)
                          if (isActive) ...[
                            Center(
                              child: Container(
                                // White background guaranteed for QR scanning
                                // — scanners need full contrast.
                                padding: EdgeInsets.all(16.w),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14.r),
                                  border: Border.all(
                                    color: Colors.grey.withValues(alpha: 0.18),
                                    width: 1,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x12000000),
                                      blurRadius: 16,
                                      offset: Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: QrImageView(
                                  data: gift.voucherCode,
                                  version: QrVersions.auto,
                                  size: 160.w,
                                  gapless: true,
                                  backgroundColor: Colors.white,
                                  eyeStyle: const QrEyeStyle(
                                    eyeShape: QrEyeShape.square,
                                    color: AppColors.mainDark,
                                  ),
                                  dataModuleStyle: const QrDataModuleStyle(
                                    dataModuleShape: QrDataModuleShape.square,
                                    color: AppColors.mainDark,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: 14.h),
                            GestureDetector(
                              onTap: () => _copyCode(context),
                              child: Center(
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 22.w, vertical: 14.h),
                                  decoration: BoxDecoration(
                                    // Neutral white chip — no pink gradient.
                                    // The discount pill above is the only
                                    // celebratory element.
                                    color: const Color(0xFFF9FAFB),
                                    borderRadius:
                                        BorderRadius.circular(14.r),
                                    border: Border.all(
                                      color: Colors.grey.withValues(alpha: 0.25),
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x08000000),
                                        blurRadius: 8,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        gift.voucherCode,
                                        style: TextStyle(
                                          fontSize: 20.sp,
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.mainDark,
                                          letterSpacing: 3,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                      SizedBox(width: 12.w),
                                      Container(
                                        width: 26.w,
                                        height: 26.w,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: color,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(Icons.copy_rounded,
                                            size: 12.sp,
                                            color: Colors.white),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: 6.h),
                            Center(
                              child: Text(
                                l.personalGiftTapToCopy,
                                style: AppTextStyles.getText3(context).copyWith(
                                  color: AppColors.mainDark
                                      .withValues(alpha: 0.50),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],

                          SizedBox(height: 14.h),

                          // Expiry info row
                          Container(
                            padding: EdgeInsets.all(12.w),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF9800)
                                  .withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(12.r),
                              border: Border.all(
                                color: const Color(0xFFFF9800)
                                    .withValues(alpha: 0.22),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today_rounded,
                                    size: 14.sp,
                                    color: const Color(0xFFE07000)),
                                SizedBox(width: 8.w),
                                Expanded(
                                  child: Text(
                                    l.personalGiftValidUntil(expiryText),
                                    style: AppTextStyles.getText2(context)
                                        .copyWith(
                                      color: const Color(0xFFB85400),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          SizedBox(height: 28.h),

                          // Close button
                          SizedBox(
                            width: double.infinity,
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                padding:
                                    EdgeInsets.symmetric(vertical: 14.h),
                                backgroundColor: AppColors.mainDark
                                    .withValues(alpha: 0.07),
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(14.r),
                                ),
                              ),
                              child: Text(
                                l.voucherPageGiftClose,
                                style: AppTextStyles.getText1(context)
                                    .copyWith(
                                  color: AppColors.mainDark,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),

                          SizedBox(height: 24.h),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
