import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/models/gift.dart';
import 'package:docsera/utils/overlay_toast.dart';

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
  final EdgeInsetsGeometry? padding;

  const GiftCard({
    super.key,
    required this.gift,
    required this.onTap,
    this.index = 0,
    this.padding,
  });

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
        return AppColors.giftAccent;
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
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, Color(0xFFFFF6EC)],
              ),
              borderRadius: BorderRadius.circular(18.r),
              border: Border.all(
                color: AppColors.giftAccent.withValues(alpha: 0.18),
                width: 0.8,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18.r),
                    child: CustomPaint(
                      painter:
                          _GiftOrbsPainter(color: color, muted: isMuted),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18.r),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: const SizedBox.shrink(),
                    ),
                  ),
                ),
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

                // Unread dot — visible only on un-opened claimed gifts.
                // Sits at the top-trailing corner of the card so it's
                // unmissable but doesn't fight the discount badge.
                if (gift.isUnread && _resolvedStatus == 'claimed')
                  PositionedDirectional(
                    top: 8.h,
                    end: 8.w,
                    child: _GiftUnreadDot(color: color),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Unread dot ──────────────────────────────────────────────────────────

class _GiftUnreadDot extends StatelessWidget {
  final Color color;
  const _GiftUnreadDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 11.r,
      height: 11.r,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(color, Colors.white, 0.20) ?? color,
            color,
          ],
        ),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.45),
            blurRadius: 6,
            spreadRadius: 0.5,
            offset: const Offset(0, 1),
          ),
        ],
      ),
    );
  }
}

// ─── Doctor avatar ────────────────────────────────────────────────────────

class _GiftDoctorAvatar extends StatelessWidget {
  final String? imageUrl;
  final Color color;
  final IconData icon;
  final double? size;

  const _GiftDoctorAvatar({
    required this.imageUrl,
    required this.color,
    required this.icon,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    final s = size ?? 46.w;
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(s / 2),
        child: CachedNetworkImage(imageUrl: imageUrl!,
          width: s,
          height: s,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => _placeholder(s, color, icon),
        ),
      );
    }
    return _placeholder(s, color, icon);
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
            color.withValues(alpha: 0.22),
            color.withValues(alpha: 0.07),
          ],
        ),
        border: Border.all(color: color.withValues(alpha: 0.30), width: 1),
      ),
      child: Icon(icon, size: size * 0.48, color: color),
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
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
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
    final lighter = Color.lerp(color, Colors.white, 0.30) ?? color;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [lighter, color],
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
//
// Composition is intentionally sibling-but-distinct from VoucherDetailPage's
// ticket hero: same perforated two-section card and dashed seam, but the
// top section is a "letter from the doctor" — avatar overlapping a warm
// orange ribbon with a "from Dr. X" tagline, then title, status, discount,
// and a quoted personal-message card framing the doctor's words. The
// bottom ticket section holds the QR + tappable code. Below the ticket
// sit the description (if any), an expiry chip, and the close button.

class GiftDetailSheet extends StatelessWidget {
  final Gift gift;

  const GiftDetailSheet({super.key, required this.gift});

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
        return AppColors.giftAccent;
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

  void _copyCode(BuildContext context) {
    HapticFeedback.selectionClick();
    Clipboard.setData(ClipboardData(text: gift.voucherCode));
    showOverlayToast(
      context,
      AppLocalizations.of(context)!.personalGiftCopied,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final color = _statusColor;
    final isActive = _resolvedStatus == 'claimed';

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
      initialChildSize: 0.92,
      minChildSize: 0.55,
      maxChildSize: 0.96,
      expand: false,
      builder: (context, scrollController) {
        return ClipRRect(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFFFF6EC), Colors.white],
                    ),
                  ),
                ),
              ),
              SingleChildScrollView(
                controller: scrollController,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 24.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: 12.h),
                    Center(
                      child: Container(
                        width: 40.w,
                        height: 4.h,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    SizedBox(height: 16.h),

                    _GiftTicketHero(
                      gift: gift,
                      color: color,
                      isActive: isActive,
                      title: title,
                      discountText: discountText,
                      statusLabel: _statusLabel(l),
                      statusIcon: _statusIcon,
                      onCopyCode: () => _copyCode(context),
                    ),

                    if (gift.message != null && gift.message!.isNotEmpty) ...[
                      SizedBox(height: 14.h),
                      _PersonalMessageCard(
                        message: gift.message!,
                        color: color,
                      ),
                    ],

                    if (description != null && description.isNotEmpty) ...[
                      SizedBox(height: 12.h),
                      _DescriptionCard(text: description, color: color),
                    ],

                    SizedBox(height: 12.h),
                    _GiftExpiryChip(
                      label: l.personalGiftValidUntil(expiryText),
                    ),

                    SizedBox(height: 22.h),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                          backgroundColor:
                              AppColors.mainDark.withValues(alpha: 0.07),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14.r),
                          ),
                        ),
                        child: Text(
                          l.voucherPageGiftClose,
                          style: AppTextStyles.getText1(context).copyWith(
                            color: AppColors.mainDark,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 8.h),
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

// ─── Gift ticket hero (perforated two-section card) ──────────────────────

class _GiftTicketHero extends StatelessWidget {
  final Gift gift;
  final Color color;
  final bool isActive;
  final String title;
  final String discountText;
  final String statusLabel;
  final IconData statusIcon;
  final VoidCallback onCopyCode;

  const _GiftTicketHero({
    required this.gift,
    required this.color,
    required this.isActive,
    required this.title,
    required this.discountText,
    required this.statusLabel,
    required this.statusIcon,
    required this.onCopyCode,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final notchY = 240.h;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.18),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
          const BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipPath(
        clipper: _TicketClipper(
          notchY: notchY,
          notchRadius: 12.r,
          borderRadius: 24.r,
        ),
        child: Stack(
          children: [
            const Positioned.fill(child: _GiftTicketBackdrop()),
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                child: const SizedBox.shrink(),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.92),
                      AppColors.giftAccent.withValues(alpha: 0.06),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.65),
                    width: 1.2,
                  ),
                ),
                padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 22.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _GiftRibbonHeader(
                      gift: gift,
                      color: color,
                      statusIcon: statusIcon,
                    ),
                    SizedBox(height: 14.h),

                    _GiftStatusPill(
                      label: statusLabel,
                      icon: statusIcon,
                      color: color,
                    ),
                    SizedBox(height: 12.h),

                    Text(
                      title,
                      style: AppTextStyles.getTitle1(context).copyWith(
                        color: AppColors.mainDark,
                        fontWeight: FontWeight.w900,
                        height: 1.25,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    if (discountText.isNotEmpty) ...[
                      SizedBox(height: 12.h),
                      _GiftDiscountChipLarge(
                        value: discountText,
                        color: color,
                      ),
                    ],

                    SizedBox(height: 28.h),

                    if (isActive) ...[
                      SizedBox(height: 8.h),
                      _GiftQrCard(code: gift.voucherCode),
                      SizedBox(height: 14.h),
                      _GiftCodeRow(
                        code: gift.voucherCode,
                        color: color,
                        onTap: onCopyCode,
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        l.personalGiftTapToCopy,
                        style: AppTextStyles.getText3(context).copyWith(
                          color: AppColors.mainDark.withValues(alpha: 0.55),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ] else ...[
                      SizedBox(height: 8.h),
                      _GiftMutedNotice(
                        label: statusLabel,
                        icon: statusIcon,
                        color: color,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            Positioned(
              left: 18.w,
              right: 18.w,
              top: notchY - 0.5,
              child: const _DashedHorizontalLine(),
            ),
          ],
        ),
      ),
    );
  }
}

class _GiftRibbonHeader extends StatelessWidget {
  final Gift gift;
  final Color color;
  final IconData statusIcon;

  const _GiftRibbonHeader({
    required this.gift,
    required this.color,
    required this.statusIcon,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.only(bottom: 32.h),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 36.h),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.giftAccentLight, AppColors.giftAccent],
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(20.r),
              bottomRight: Radius.circular(20.r),
            ),
          ),
          child: Column(
            children: [
              Text(
                l.voucherPageGiftDetailTitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                l.voucherPageGiftSentBy(gift.doctorName),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        Positioned(
          bottom: -32.h,
          child: Container(
            padding: EdgeInsets.all(3.w),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: _GiftDoctorAvatar(
              imageUrl: gift.doctorImage,
              color: color,
              icon: statusIcon,
              size: 64.w,
            ),
          ),
        ),
        ],
      ),
    );
  }
}

class _GiftDiscountChipLarge extends StatelessWidget {
  final String value;
  final Color color;
  const _GiftDiscountChipLarge({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final lighter = Color.lerp(color, Colors.white, 0.30) ?? color;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 8.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [lighter, color],
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
          Icon(Icons.local_offer_rounded, size: 14.sp, color: Colors.white),
          SizedBox(width: 6.w),
          Text(
            value,
            style: TextStyle(
              fontSize: 15.sp,
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

class _GiftQrCard extends StatelessWidget {
  final String code;
  const _GiftQrCard({required this.code});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(
          color: AppColors.giftAccent.withValues(alpha: 0.18),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.giftAccent.withValues(alpha: 0.10),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: QrImageView(
        data: code,
        version: QrVersions.auto,
        size: 168.w,
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
    );
  }
}

class _GiftCodeRow extends StatelessWidget {
  final String code;
  final Color color;
  final VoidCallback onTap;

  const _GiftCodeRow({
    required this.code,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 14.h),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.10),
              const Color(0xFFFFF6EC),
            ],
          ),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: color.withValues(alpha: 0.25)),
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
                  size: 13.sp, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _GiftMutedNotice extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _GiftMutedNotice({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
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
          Icon(icon, color: color, size: 18.sp),
          SizedBox(width: 8.w),
          Text(
            label,
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

class _GiftTicketBackdrop extends StatelessWidget {
  const _GiftTicketBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: Colors.white),
      child: CustomPaint(
        painter: _GiftHeroOrbsPainter(),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _GiftHeroOrbsPainter extends CustomPainter {
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
      Offset(size.width * 0.15, size.height * 0.10),
      size.width * 0.55,
      AppColors.giftAccent.withValues(alpha: 0.32),
    );
    orb(
      Offset(size.width * 0.85, size.height * 0.08),
      size.width * 0.45,
      AppColors.giftAccentLight.withValues(alpha: 0.28),
    );
    orb(
      Offset(size.width * 0.50, size.height * 0.95),
      size.width * 0.65,
      AppColors.giftAccent.withValues(alpha: 0.10),
    );
    orb(
      Offset(size.width * 0.92, size.height * 0.78),
      size.width * 0.30,
      AppColors.yellow.withValues(alpha: 0.10),
    );
  }

  @override
  bool shouldRepaint(covariant _GiftHeroOrbsPainter oldDelegate) => false;
}

class _TicketClipper extends CustomClipper<Path> {
  final double notchY;
  final double notchRadius;
  final double borderRadius;

  _TicketClipper({
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
      ..lineTo(size.width, y - n)
      ..arcToPoint(Offset(size.width, y + n),
          radius: Radius.circular(n), clockwise: false)
      ..lineTo(size.width, size.height - r)
      ..arcToPoint(Offset(size.width - r, size.height),
          radius: Radius.circular(r))
      ..lineTo(r, size.height)
      ..arcToPoint(Offset(0, size.height - r), radius: Radius.circular(r))
      ..lineTo(0, y + n)
      ..arcToPoint(Offset(0, y - n),
          radius: Radius.circular(n), clockwise: false)
      ..lineTo(0, r)
      ..arcToPoint(Offset(r, 0), radius: Radius.circular(r))
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant _TicketClipper oldClipper) =>
      oldClipper.notchY != notchY ||
      oldClipper.notchRadius != notchRadius ||
      oldClipper.borderRadius != borderRadius;
}

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

// ─── Personal message card ───────────────────────────────────────────────

class _PersonalMessageCard extends StatelessWidget {
  final String message;
  final Color color;
  const _PersonalMessageCard({required this.message, required this.color});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
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
                color: color.withValues(alpha: 0.18),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0F000000),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 16.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 28.w,
                      height: 28.w,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            color.withValues(alpha: 0.22),
                            color.withValues(alpha: 0.06),
                          ],
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: color.withValues(alpha: 0.25),
                          width: 0.8,
                        ),
                      ),
                      child: Icon(Icons.format_quote_rounded,
                          size: 14.sp, color: color),
                    ),
                    SizedBox(width: 10.w),
                    Text(
                      l.voucherPageGiftDoctorMessageHeading,
                      style: AppTextStyles.getText1(context).copyWith(
                        color: AppColors.mainDark,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10.h),
                Text(
                  '“$message”',
                  style: AppTextStyles.getText2(context).copyWith(
                    color: Colors.black87,
                    height: 1.55,
                    fontStyle: FontStyle.italic,
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

class _DescriptionCard extends StatelessWidget {
  final String text;
  final Color color;
  const _DescriptionCard({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Text(
        text,
        style: AppTextStyles.getText2(context).copyWith(
          color: AppColors.mainDark.withValues(alpha: 0.78),
          height: 1.5,
        ),
      ),
    );
  }
}

class _GiftExpiryChip extends StatelessWidget {
  final String label;
  const _GiftExpiryChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: const Color(0xFFFF9800).withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: const Color(0xFFFF9800).withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_today_rounded,
              size: 14.sp, color: const Color(0xFFE07000)),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.getText2(context).copyWith(
                color: const Color(0xFFB85400),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
