import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/models/offer_model.dart';

class OfferCard extends StatelessWidget {
  final OfferModel offer;
  final VoidCallback onTap;

  const OfferCard({super.key, required this.offer, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14.r),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14.r),
          border: offer.isMegaOffer
              ? Border.all(color: Colors.amber, width: 2)
              : null,
          boxShadow: [
            BoxShadow(color: Colors.grey.withOpacity(0.15), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            // Partner logo or category icon
            Container(
              width: 50.w,
              height: 50.w,
              decoration: BoxDecoration(
                color: AppColors.main.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: offer.partnerLogoUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12.r),
                      child: Image.network(offer.partnerLogoUrl!, fit: BoxFit.cover),
                    )
                  : Icon(
                      offer.category == 'credit' ? Icons.phone_android : Icons.local_offer,
                      color: AppColors.main,
                      size: 24.sp,
                    ),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (offer.isMegaOffer)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                      margin: EdgeInsets.only(bottom: 4.h),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                      child: Text(
                        'MEGA',
                        style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.bold, color: Colors.amber[800]),
                      ),
                    ),
                  Text(
                    offer.getLocalizedTitle(locale),
                    style: AppTextStyles.getText2(context).copyWith(fontWeight: FontWeight.w700),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (offer.getLocalizedPartnerName(locale) != null) ...[
                    SizedBox(height: 2.h),
                    Text(
                      offer.getLocalizedPartnerName(locale)!,
                      style: AppTextStyles.getText3(context).copyWith(color: Colors.grey),
                    ),
                  ],
                ],
              ),
            ),
            Column(
              children: [
                Text(
                  '${offer.pointsCost}',
                  style: AppTextStyles.getTitle1(context).copyWith(color: AppColors.main),
                ),
                Text(
                  AppLocalizations.of(context)!.points,
                  style: AppTextStyles.getText3(context).copyWith(color: AppColors.main),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
