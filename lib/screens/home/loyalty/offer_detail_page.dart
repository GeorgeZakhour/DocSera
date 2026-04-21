import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/models/offer_model.dart';
import 'package:docsera/Business_Logic/Loyalty/offers/offers_cubit.dart';
import 'package:docsera/Business_Logic/Loyalty/offers/offers_state.dart';
import 'package:docsera/Business_Logic/Account_page/user_cubit.dart';
import 'package:docsera/Business_Logic/Account_page/user_state.dart';

class OfferDetailPage extends StatelessWidget {
  final OfferModel offer;

  const OfferDetailPage({super.key, required this.offer});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;

    return Scaffold(
      backgroundColor: AppColors.background2,
      appBar: AppBar(
        backgroundColor: AppColors.main,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          AppLocalizations.of(context)!.offerDetails,
          style: AppTextStyles.getTitle1(context).copyWith(color: Colors.white),
        ),
      ),
      body: BlocListener<OffersCubit, OffersState>(
        listener: (context, state) {
          if (state is OfferRedeemSuccess) {
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                title: Row(
                  children: [
                    Icon(Icons.check_circle, color: AppColors.main, size: 24.sp),
                    SizedBox(width: 8.w),
                    Text(AppLocalizations.of(context)!.redeemSuccess),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(AppLocalizations.of(context)!.yourVoucherCode),
                    SizedBox(height: 12.h),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                      decoration: BoxDecoration(
                        color: AppColors.main.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Text(
                        state.voucherCode,
                        style: TextStyle(
                          fontSize: 22.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.main,
                          letterSpacing: 3,
                        ),
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context); // Close dialog
                      Navigator.pop(context); // Go back to offers
                    },
                    child: Text(AppLocalizations.of(context)!.done, style: TextStyle(color: AppColors.main)),
                  ),
                ],
              ),
            );
          } else if (state is OfferRedeemError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.error), backgroundColor: Colors.red),
            );
          }
        },
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Offer title
              Text(
                offer.getLocalizedTitle(locale),
                style: AppTextStyles.getTitle1(context).copyWith(fontSize: 20.sp),
              ),
              SizedBox(height: 12.h),

              // Partner info
              if (offer.getLocalizedPartnerName(locale) != null) ...[
                Row(
                  children: [
                    Icon(Icons.store, size: 16.sp, color: Colors.grey),
                    SizedBox(width: 8.w),
                    Text(offer.getLocalizedPartnerName(locale)!, style: AppTextStyles.getText2(context)),
                  ],
                ),
                SizedBox(height: 6.h),
              ],

              if (offer.getLocalizedPartnerAddress(locale) != null) ...[
                Row(
                  children: [
                    Icon(Icons.location_on, size: 16.sp, color: Colors.grey),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(offer.getLocalizedPartnerAddress(locale)!, style: AppTextStyles.getText3(context)),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
              ],

              // Description
              if (offer.getLocalizedDescription(locale) != null) ...[
                Text(offer.getLocalizedDescription(locale)!, style: AppTextStyles.getText2(context)),
                SizedBox(height: 16.h),
              ],

              // Discount info
              if (offer.discountValue != null)
                Container(
                  padding: EdgeInsets.all(14.w),
                  decoration: BoxDecoration(
                    color: AppColors.main.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.discount, color: AppColors.main, size: 20.sp),
                      SizedBox(width: 10.w),
                      Text(
                        offer.discountType == 'percentage'
                            ? '${offer.discountValue!.toInt()}% ${AppLocalizations.of(context)!.discount}'
                            : '${offer.discountValue!.toInt()} SYP ${AppLocalizations.of(context)!.discount}',
                        style: AppTextStyles.getTitle1(context).copyWith(color: AppColors.main),
                      ),
                    ],
                  ),
                ),

              SizedBox(height: 24.h),

              // Points cost + redeem button
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14.r),
                  boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 4)],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.stars, color: AppColors.main, size: 20.sp),
                        SizedBox(width: 8.w),
                        Text(
                          '${offer.pointsCost} ${AppLocalizations.of(context)!.points}',
                          style: AppTextStyles.getTitle1(context).copyWith(color: AppColors.main, fontSize: 18.sp),
                        ),
                      ],
                    ),
                    SizedBox(height: 16.h),
                    BlocBuilder<UserCubit, UserState>(
                      builder: (context, userState) {
                        final hasEnough = userState is UserLoaded && userState.userPoints >= offer.pointsCost;

                        return SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: hasEnough ? () => _confirmRedeem(context) : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.main,
                              disabledBackgroundColor: Colors.grey[300],
                              padding: EdgeInsets.symmetric(vertical: 14.h),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                            ),
                            child: Text(
                              hasEnough
                                  ? AppLocalizations.of(context)!.redeemNow
                                  : AppLocalizations.of(context)!.notEnoughPoints,
                              style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w600),
                            ),
                          ),
                        );
                      },
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

  void _confirmRedeem(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
        title: Text(AppLocalizations.of(context)!.confirmRedeem),
        content: Text(
          '${AppLocalizations.of(context)!.spendPoints} ${offer.pointsCost} ${AppLocalizations.of(context)!.points}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel, style: const TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<OffersCubit>().redeemOffer(offer.id);
            },
            child: Text(AppLocalizations.of(context)!.confirm, style: const TextStyle(color: AppColors.main)),
          ),
        ],
      ),
    );
  }
}
