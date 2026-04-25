import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:docsera/utils/color_utils.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'partner_profile_page.dart';

class OfferDetailPage extends StatefulWidget {
  final OfferModel offer;

  const OfferDetailPage({super.key, required this.offer});

  @override
  State<OfferDetailPage> createState() => _OfferDetailPageState();
}

class _OfferDetailPageState extends State<OfferDetailPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.6, curve: Curves.easeOut)),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.1, 0.8, curve: Curves.easeOutCubic)),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final brand = colorFromHex(widget.offer.partnerBrandColor, fallback: AppColors.main);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        body: BlocListener<OffersCubit, OffersState>(
          listener: (context, state) {
            if (state is OfferRedeemSuccess) {
              _showSuccessDialog(context, state.voucherCode);
              // Refresh offers list so currentRedemptions / partner_offer_count
              // reflect the redemption when the user pops back to OffersPage.
              context.read<OffersCubit>().loadOffers();
            } else if (state is OfferRedeemError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.error),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                ),
              );
            }
          },
          child: SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: CustomScrollView(
                slivers: [
                  SliverAppBar(
                    expandedHeight: 220.h,
                    pinned: true,
                    backgroundColor: brand,
                    iconTheme: const IconThemeData(color: Colors.white),
                    flexibleSpace: FlexibleSpaceBar(
                      background: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (widget.offer.imageUrl != null)
                            Image.network(
                              widget.offer.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _heroFallback(brand),
                            )
                          else
                            _heroFallback(brand),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withOpacity(0.05),
                                  Colors.black.withOpacity(0.55),
                                ],
                              ),
                            ),
                          ),
                          if (widget.offer.isMegaOffer)
                            PositionedDirectional(
                              top: kToolbarHeight + 8.h,
                              start: 16.w,
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF8F00),
                                  borderRadius: BorderRadius.circular(6.r),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.local_fire_department_rounded,
                                        size: 12.sp, color: Colors.white),
                                    SizedBox(width: 4.w),
                                    Text(
                                      AppLocalizations.of(context)!.megaOffer,
                                      style: TextStyle(
                                        fontSize: 10.sp,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          PositionedDirectional(
                            bottom: 16.h,
                            start: 16.w,
                            end: 16.w,
                            child: Text(
                              widget.offer.getLocalizedTitle(locale),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22.sp,
                                fontWeight: FontWeight.w800,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(16.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.offer.partnerId != null) _buildPartnerMiniCard(context),
                          if (widget.offer.getLocalizedDescription(locale) != null) ...[
                            SizedBox(height: 16.h),
                            _buildDescriptionCard(context, locale),
                          ],
                          if (widget.offer.discountValue != null) ...[
                            SizedBox(height: 16.h),
                            _buildDiscountCard(context),
                          ],
                          SizedBox(height: 24.h),
                          _buildRedeemSection(context),
                          SizedBox(height: 24.h),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _heroFallback(Color brand) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [brand, brand.withOpacity(0.75)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Icon(
            widget.offer.category == 'credit'
                ? Icons.phone_android_rounded
                : Icons.local_offer_rounded,
            color: Colors.white.withOpacity(0.35),
            size: 80.sp,
          ),
        ),
      );

  Widget _buildPartnerMiniCard(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final name = widget.offer.getLocalizedPartnerName(locale) ?? '';
    final others = widget.offer.partnerOfferCount > 1
        ? widget.offer.partnerOfferCount - 1
        : 0;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        fadePageRoute(PartnerProfilePage(partnerId: widget.offer.partnerId!)),
      ),
      child: Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44.w,
              height: 44.w,
              decoration: BoxDecoration(
                color: AppColors.main.withOpacity(0.06),
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child: widget.offer.partnerLogoUrl != null
                    ? Image.network(
                        widget.offer.partnerLogoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Icon(Icons.store_rounded, color: AppColors.main),
                      )
                    : Icon(Icons.store_rounded, color: AppColors.main),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: AppTextStyles.getText2(context).copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.mainDark,
                    ),
                  ),
                  if (others > 0)
                    Text(
                      l.viewAllOffersFromPartner(others),
                      style: AppTextStyles.getText3(context).copyWith(
                        color: AppColors.main,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.main, size: 22.sp),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionCard(BuildContext context, String locale) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: 16.h),
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        widget.offer.getLocalizedDescription(locale)!,
        style: AppTextStyles.getText2(context).copyWith(
          height: 1.6,
          color: Colors.grey[700],
        ),
      ),
    );
  }

  Widget _buildDiscountCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.main.withOpacity(0.08), AppColors.main.withOpacity(0.03)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.main.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: AppColors.main.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(Icons.discount_rounded, color: AppColors.main, size: 22.sp),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.discount,
                  style: AppTextStyles.getText3(context).copyWith(
                    color: AppColors.main.withOpacity(0.7),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  widget.offer.discountType == 'percentage'
                      ? '${widget.offer.discountValue!.toInt()}%'
                      : '${widget.offer.discountValue!.toInt()} ${AppLocalizations.of(context)!.currency}',
                  style: TextStyle(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w800,
                    color: AppColors.main,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRedeemSection(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        boxShadow: [
          BoxShadow(
            color: AppColors.main.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Points cost display
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.main.withOpacity(0.08), AppColors.main.withOpacity(0.03)],
              ),
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.stars_rounded, color: AppColors.main, size: 22.sp),
                SizedBox(width: 10.w),
                Text(
                  '${widget.offer.pointsCost}',
                  style: TextStyle(
                    fontSize: 28.sp,
                    fontWeight: FontWeight.w800,
                    color: AppColors.main,
                  ),
                ),
                SizedBox(width: 6.w),
                Text(
                  AppLocalizations.of(context)!.points,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.main.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 18.h),

          // Redeem button
          BlocBuilder<UserCubit, UserState>(
            builder: (context, userState) {
              final hasEnough = userState is UserLoaded &&
                  userState.userPoints >= widget.offer.pointsCost;

              return SizedBox(
                width: double.infinity,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  child: ElevatedButton(
                    onPressed: hasEnough ? () => _confirmRedeem(context) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.main,
                      disabledBackgroundColor: Colors.grey[300],
                      padding: EdgeInsets.symmetric(vertical: 16.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                      elevation: hasEnough ? 4 : 0,
                      shadowColor: AppColors.main.withOpacity(0.3),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          hasEnough ? Icons.redeem_rounded : Icons.lock_rounded,
                          color: Colors.white,
                          size: 20.sp,
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          hasEnough
                              ? AppLocalizations.of(context)!.redeemNow
                              : AppLocalizations.of(context)!.notEnoughPoints,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          // Current balance hint
          BlocBuilder<UserCubit, UserState>(
            builder: (context, userState) {
              if (userState is! UserLoaded) return const SizedBox();
              return Padding(
                padding: EdgeInsets.only(top: 10.h),
                child: Text(
                  '${AppLocalizations.of(context)!.yourPoints}: ${userState.userPoints}',
                  style: AppTextStyles.getText3(context).copyWith(
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _confirmRedeem(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final validityDays = widget.offer.voucherValidityDays;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 32.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            SizedBox(height: 20.h),

            // Warning icon
            Container(
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.info_outline_rounded, size: 30.sp, color: const Color(0xFFFF9800)),
            ),
            SizedBox(height: 14.h),

            Text(
              l.redeemWarningTitle,
              style: AppTextStyles.getTitle2(context).copyWith(
                color: AppColors.mainDark,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 16.h),

            // Warning items
            _buildWarningItem(
              context,
              Icons.confirmation_number_rounded,
              l.redeemWarningVoucher,
              AppColors.main,
            ),
            SizedBox(height: 10.h),
            _buildWarningItem(
              context,
              Icons.timer_rounded,
              l.redeemWarningValidity(validityDays),
              const Color(0xFFFF9800),
            ),
            SizedBox(height: 10.h),
            _buildWarningItem(
              context,
              Icons.block_rounded,
              l.redeemWarningIrreversible,
              const Color(0xFFE53935),
            ),
            SizedBox(height: 10.h),
            _buildWarningItem(
              context,
              Icons.qr_code_rounded,
              l.redeemWarningUseIt,
              Colors.grey[600]!,
            ),

            SizedBox(height: 8.h),

            // Points cost reminder
            Container(
              width: double.infinity,
              margin: EdgeInsets.only(top: 10.h),
              padding: EdgeInsets.symmetric(vertical: 10.h),
              decoration: BoxDecoration(
                color: AppColors.main.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.stars_rounded, size: 16.sp, color: AppColors.main),
                  SizedBox(width: 6.w),
                  Text(
                    l.redeemConfirmMessage(widget.offer.pointsCost),
                    style: AppTextStyles.getText3(context).copyWith(
                      color: AppColors.main,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 20.h),

            // Buttons
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.read<OffersCubit>().redeemOffer(widget.offer.id);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.main,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                child: Text(
                  l.iUnderstandRedeem,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            SizedBox(height: 10.h),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  l.cancel,
                  style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWarningItem(BuildContext context, IconData icon, String text, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: EdgeInsets.only(top: 2.h),
          padding: EdgeInsets.all(5.w),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(6.r),
          ),
          child: Icon(icon, size: 14.sp, color: color),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.getText2(context).copyWith(
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  void _showSuccessDialog(BuildContext context, String code) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_circle_rounded, color: const Color(0xFF4CAF50), size: 48.sp),
              ),
              SizedBox(height: 16.h),
              Text(
                AppLocalizations.of(context)!.redeemSuccess,
                style: AppTextStyles.getTitle2(context).copyWith(
                  color: AppColors.mainDark,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                AppLocalizations.of(context)!.yourVoucherCode,
                style: AppTextStyles.getText2(context).copyWith(color: Colors.grey[600]),
              ),
              SizedBox(height: 16.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 14.h),
                decoration: BoxDecoration(
                  color: AppColors.main.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: AppColors.main.withOpacity(0.2)),
                ),
                child: Text(
                  code,
                  style: TextStyle(
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w800,
                    color: AppColors.main,
                    letterSpacing: 3,
                  ),
                ),
              ),
              SizedBox(height: 24.h),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.main,
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.goToVouchers,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
