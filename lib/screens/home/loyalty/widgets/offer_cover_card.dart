import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/models/offer_model.dart';
import 'package:docsera/utils/color_utils.dart';

class OfferCoverCard extends StatelessWidget {
  final OfferModel offer;
  final VoidCallback onTap;
  final int index;

  const OfferCoverCard({
    super.key,
    required this.offer,
    required this.onTap,
    this.index = 0,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final brand = colorFromHex(offer.partnerBrandColor, fallback: AppColors.main);
    final remaining = offer.remainingRedemptions;
    final showLowStock = remaining != null && remaining < 20 && remaining > 0;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 380 + (index * 50)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Transform.translate(
        offset: Offset(0, 18 * (1 - value)),
        child: Opacity(opacity: value, child: child),
      ),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 180.h,
          margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18.r),
            child: Column(
              children: [
                Expanded(
                  flex: 6,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildCover(brand),
                      // Dark gradient overlay for legibility
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.35),
                            ],
                          ),
                        ),
                      ),
                      if (offer.isMegaOffer)
                        PositionedDirectional(
                          top: 10.h,
                          start: 10.w,
                          child: _ribbon(l.megaOffer),
                        ),
                      if (showLowStock)
                        PositionedDirectional(
                          top: 10.h,
                          end: 10.w,
                          child: _lowStockBadge(l.xLeft(remaining)),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(14.w, 10.h, 14.w, 10.h),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                offer.getLocalizedTitle(locale),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.getText2(context).copyWith(
                                  fontWeight: FontWeight.w800,
                                  height: 1.2,
                                ),
                              ),
                              if (offer.getLocalizedPartnerName(locale) != null) ...[
                                SizedBox(height: 4.h),
                                Row(
                                  children: [
                                    if (offer.partnerLogoUrl != null) ...[
                                      ClipOval(
                                        child: Image.network(
                                          offer.partnerLogoUrl!,
                                          width: 16.w,
                                          height: 16.w,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              Icon(Icons.store_rounded, size: 12.sp, color: Colors.grey[500]),
                                        ),
                                      ),
                                      SizedBox(width: 6.w),
                                    ],
                                    Expanded(
                                      child: Text(
                                        offer.getLocalizedPartnerName(locale)!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTextStyles.getText3(context)
                                            .copyWith(color: Colors.grey[600]),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        SizedBox(width: 10.w),
                        _pointsPill(),
                      ],
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

  Widget _buildCover(Color brand) {
    if (offer.imageUrl != null && offer.imageUrl!.isNotEmpty) {
      return Image.network(
        offer.imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _gradientFallback(brand),
      );
    }
    return _gradientFallback(brand);
  }

  Widget _gradientFallback(Color brand) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [brand, brand.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          offer.category == 'credit'
              ? Icons.phone_android_rounded
              : Icons.local_offer_rounded,
          color: Colors.white.withOpacity(0.4),
          size: 56.sp,
        ),
      ),
    );
  }

  Widget _ribbon(String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF8F00), Color(0xFFFFB300)],
        ),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department_rounded, size: 12.sp, color: Colors.white),
          SizedBox(width: 4.w),
          Text(
            text,
            style: TextStyle(
              fontSize: 10.sp,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _lowStockBadge(String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: const Color(0xFFE53935).withOpacity(0.92),
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10.sp,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _pointsPill() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.main.withOpacity(0.10), AppColors.main.withOpacity(0.04)],
        ),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.stars_rounded, size: 14.sp, color: AppColors.main),
          SizedBox(width: 4.w),
          Text(
            '${offer.pointsCost}',
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.main,
            ),
          ),
        ],
      ),
    );
  }
}
