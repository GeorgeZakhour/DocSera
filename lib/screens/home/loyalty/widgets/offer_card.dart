import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/models/offer_model.dart';

class OfferCard extends StatelessWidget {
  final OfferModel offer;
  final VoidCallback onTap;
  final int index;

  const OfferCard({super.key, required this.offer, required this.onTap, this.index = 0});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + (index * 60)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 24 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18.r),
            border: offer.isMegaOffer
                ? Border.all(color: const Color(0xFFFFB300), width: 1.5)
                : null,
            boxShadow: [
              BoxShadow(
                color: offer.isMegaOffer
                    ? const Color(0xFFFFB300).withOpacity(0.15)
                    : Colors.black.withOpacity(0.04),
                blurRadius: offer.isMegaOffer ? 12 : 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              // Mega offer banner
              if (offer.isMegaOffer)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 6.h),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF8F00), Color(0xFFFFB300)],
                    ),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(17.r)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.local_fire_department_rounded, size: 14.sp, color: Colors.white),
                      SizedBox(width: 4.w),
                      Text(
                        AppLocalizations.of(context)!.megaOffer,
                        style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),

              // Card content
              Padding(
                padding: EdgeInsets.all(16.w),
                child: Row(
                  children: [
                    // Logo/icon
                    Container(
                      width: 54.w,
                      height: 54.w,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.main.withOpacity(0.08),
                            AppColors.main.withOpacity(0.03),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                      child: offer.partnerLogoUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(14.r),
                              child: Image.network(
                                offer.partnerLogoUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(
                                  Icons.local_offer_rounded,
                                  color: AppColors.main,
                                  size: 24.sp,
                                ),
                              ),
                            )
                          : Icon(
                              offer.category == 'credit'
                                  ? Icons.phone_android_rounded
                                  : Icons.local_offer_rounded,
                              color: AppColors.main,
                              size: 26.sp,
                            ),
                    ),
                    SizedBox(width: 14.w),

                    // Title & partner
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            offer.getLocalizedTitle(locale),
                            style: AppTextStyles.getText2(context).copyWith(
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (offer.getLocalizedPartnerName(locale) != null) ...[
                            SizedBox(height: 4.h),
                            Row(
                              children: [
                                Icon(Icons.store_rounded, size: 12.sp, color: Colors.grey[400]),
                                SizedBox(width: 4.w),
                                Expanded(
                                  child: Text(
                                    offer.getLocalizedPartnerName(locale)!,
                                    style: AppTextStyles.getText3(context).copyWith(color: Colors.grey[500]),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    SizedBox(width: 10.w),

                    // Points cost
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.main.withOpacity(0.08), AppColors.main.withOpacity(0.04)],
                        ),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${offer.pointsCost}',
                            style: TextStyle(
                              fontSize: 17.sp,
                              fontWeight: FontWeight.w800,
                              color: AppColors.main,
                            ),
                          ),
                          Text(
                            AppLocalizations.of(context)!.points,
                            style: TextStyle(
                              fontSize: 10.sp,
                              color: AppColors.main.withOpacity(0.7),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
