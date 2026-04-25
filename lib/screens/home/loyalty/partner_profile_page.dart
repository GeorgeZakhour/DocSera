import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/Business_Logic/Loyalty/partner/partner_cubit.dart';
import 'package:docsera/Business_Logic/Loyalty/partner/partner_state.dart';
import 'package:docsera/services/supabase/loyalty/loyalty_service.dart';
import 'package:docsera/utils/color_utils.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'offer_detail_page.dart';
import 'widgets/offer_cover_card.dart';

class PartnerProfilePage extends StatelessWidget {
  final String partnerId;

  const PartnerProfilePage({super.key, required this.partnerId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => PartnerCubit(LoyaltyService())..load(partnerId),
      child: const _PartnerProfileView(),
    );
  }
}

class _PartnerProfileView extends StatelessWidget {
  const _PartnerProfileView();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        body: BlocBuilder<PartnerCubit, PartnerState>(
          builder: (context, state) {
            if (state is PartnerLoading || state is PartnerInitial) {
              return _scaffoldShell(
                title: '',
                body: const Center(
                  child: CircularProgressIndicator(color: AppColors.main),
                ),
              );
            }
            if (state is PartnerError) {
              return _scaffoldShell(
                title: l.partnerUnavailable,
                body: Center(child: Text(state.message)),
              );
            }
            if (state is PartnerNotFound) {
              return _scaffoldShell(
                title: l.partnerUnavailable,
                body: Center(child: Text(l.partnerUnavailable)),
              );
            }
            return _buildLoaded(context, state as PartnerLoaded, l);
          },
        ),
      ),
    );
  }

  Widget _scaffoldShell({required String title, required Widget body}) {
    return Builder(
      builder: (context) => CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: const Color(0xFF007E80),
            iconTheme: const IconThemeData(color: Colors.white),
            title: Text(
              title,
              style: AppTextStyles.getTitle1(context).copyWith(color: Colors.white),
            ),
          ),
          SliverFillRemaining(child: body),
        ],
      ),
    );
  }

  Widget _buildLoaded(BuildContext context, PartnerLoaded state, AppLocalizations l) {
    final locale = Localizations.localeOf(context).languageCode;
    final brand = colorFromHex(state.partner.brandColor, fallback: AppColors.main);
    final name = state.partner.getLocalizedName(locale);
    final address = state.partner.getLocalizedAddress(locale);
    final about = state.partner.getLocalizedAbout(locale);

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 200.h,
          pinned: true,
          backgroundColor: brand,
          iconTheme: const IconThemeData(color: Colors.white),
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                if (state.partner.coverUrl != null)
                  Image.network(
                    state.partner.coverUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _brandGradient(brand),
                  )
                else
                  _brandGradient(brand),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.05),
                        Colors.black.withOpacity(0.45),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Transform.translate(
            offset: Offset(0, -36.h),
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 16.w),
              padding: EdgeInsets.all(16.w),
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
              child: Row(
                children: [
                  Container(
                    width: 64.w,
                    height: 64.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: brand, width: 2),
                      color: brand.withOpacity(0.06),
                    ),
                    padding: EdgeInsets.all(3.w),
                    child: ClipOval(
                      child: state.partner.logoUrl != null
                          ? Image.network(
                              state.partner.logoUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  Icon(Icons.store_rounded, color: brand),
                            )
                          : Icon(Icons.store_rounded, color: brand),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: AppTextStyles.getTitle2(context).copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.mainDark,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                          decoration: BoxDecoration(
                            color: brand.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(6.r),
                          ),
                          child: Text(
                            l.partnerBadge,
                            style: TextStyle(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w700,
                              color: brand,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 8.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (address != null && address.isNotEmpty)
                  _infoRow(context, Icons.location_on_rounded, address,
                      onTap: () => _openMap(address)),
                if (state.partner.phone != null && state.partner.phone!.isNotEmpty) ...[
                  SizedBox(height: 6.h),
                  _infoRow(context, Icons.phone_rounded, state.partner.phone!,
                      onTap: () => _dial(state.partner.phone!)),
                ],
              ],
            ),
          ),
        ),
        if (about != null && about.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 8.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.aboutPartner,
                    style: AppTextStyles.getTitle3(context).copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.mainDark,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Container(
                    padding: EdgeInsets.all(14.w),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      about,
                      style: AppTextStyles.getText2(context)
                          .copyWith(color: Colors.grey[700], height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16.w, 18.h, 16.w, 8.h),
            child: Text(
              '${l.allOffersTitle} (${state.offers.length})',
              style: AppTextStyles.getTitle3(context).copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.mainDark,
              ),
            ),
          ),
        ),
        if (state.offers.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
              child: Text(
                l.noActiveOffersFromPartner,
                style: AppTextStyles.getText2(context).copyWith(color: Colors.grey[500]),
              ),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) => OfferCoverCard(
                offer: state.offers[i],
                index: i,
                onTap: () => Navigator.push(
                  context,
                  fadePageRoute(OfferDetailPage(offer: state.offers[i])),
                ),
              ),
              childCount: state.offers.length,
            ),
          ),
        SliverToBoxAdapter(child: SizedBox(height: 24.h)),
      ],
    );
  }

  Widget _brandGradient(Color brand) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [brand, brand.withOpacity(0.75)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }

  Widget _infoRow(BuildContext context, IconData icon, String text, {VoidCallback? onTap}) {
    final row = Row(
      children: [
        Icon(icon, size: 16.sp, color: AppColors.main),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.getText2(context).copyWith(color: Colors.grey[700]),
          ),
        ),
      ],
    );
    return onTap == null ? row : InkWell(onTap: onTap, child: row);
  }

  Future<void> _dial(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _openMap(String address) async {
    final uri = Uri.parse('https://maps.google.com/?q=${Uri.encodeComponent(address)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
