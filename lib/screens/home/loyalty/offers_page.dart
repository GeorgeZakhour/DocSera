import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/Business_Logic/Loyalty/offers/offers_cubit.dart';
import 'package:docsera/Business_Logic/Loyalty/offers/offers_state.dart';
import 'package:docsera/Business_Logic/Account_page/user_cubit.dart';
import 'package:docsera/Business_Logic/Account_page/user_state.dart';
import 'package:docsera/models/offer_model.dart';
import 'package:docsera/models/partner_model.dart';
import 'package:docsera/utils/color_utils.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'offer_detail_page.dart';
import 'partner_profile_page.dart';
import 'widgets/category_chip.dart';
import 'widgets/offer_cover_card.dart';
import 'widgets/partner_bubble.dart';

class OffersPage extends StatefulWidget {
  const OffersPage({super.key});

  @override
  State<OffersPage> createState() => _OffersPageState();
}

class _OffersPageState extends State<OffersPage> {
  String _activeFilter = 'all'; // 'all' | partner_type value | 'credit'

  @override
  void initState() {
    super.initState();
    context.read<OffersCubit>().loadOffers();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        body: BlocBuilder<OffersCubit, OffersState>(
          builder: (context, state) {
            return RefreshIndicator(
              color: AppColors.main,
              onRefresh: () => context.read<OffersCubit>().loadOffers(),
              child: CustomScrollView(
                slivers: [
                  _buildHero(context, l),
                  if (state is OffersLoading)
                    const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator(color: AppColors.main)),
                    )
                  else if (state is OffersError)
                    SliverFillRemaining(child: Center(child: Text(state.message)))
                  else if (state is OffersLoaded) ...[
                    _buildChips(context, l, state),
                    if (_filteredMega(state).isNotEmpty)
                      _buildMegaCarousel(context, l, _filteredMega(state)),
                    if (_partners(state).length >= 2)
                      _buildFeaturedPartners(context, l, _partners(state)),
                    _buildOfferListHeader(context, l),
                    ..._buildOfferList(context, _filteredAll(state)),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Filters ──────────────────────────────────────────────────────
  bool _matchesFilter(OfferModel o) {
    if (_activeFilter == 'all') return true;
    if (_activeFilter == 'credit') return o.category == 'credit';
    return o.partnerType == _activeFilter;
  }

  List<OfferModel> _filteredAll(OffersLoaded s) =>
      s.allOffers.where(_matchesFilter).toList(growable: false);

  List<OfferModel> _filteredMega(OffersLoaded s) =>
      s.allOffers.where((o) => o.isMegaOffer && _matchesFilter(o)).toList(growable: false);

  List<PartnerModel> _partners(OffersLoaded s) {
    final byId = <String, PartnerModel>{};
    final counts = <String, int>{};
    for (final o in s.allOffers) {
      if (o.partnerId == null || o.partnerName == null) continue;
      counts[o.partnerId!] = (counts[o.partnerId!] ?? 0) + 1;
      byId.putIfAbsent(o.partnerId!, () => PartnerModel(
            id: o.partnerId!,
            name: o.partnerName!,
            nameAr: o.partnerNameAr,
            logoUrl: o.partnerLogoUrl,
            brandColor: o.partnerBrandColor,
            partnerType: o.partnerType,
          ));
    }
    final list = byId.values.toList()
      ..sort((a, b) => (counts[b.id] ?? 0).compareTo(counts[a.id] ?? 0));
    return list.take(12).toList();
  }

  List<({String key, String label, IconData? icon})> _buildChipDefs(
      AppLocalizations l, OffersLoaded s) {
    final types = <String>{
      for (final o in s.allOffers)
        if (o.partnerType != null) o.partnerType!,
    };
    final defs = <({String key, String label, IconData? icon})>[
      (key: 'all', label: l.all, icon: Icons.dashboard_rounded),
    ];
    if (types.contains('pharmacy')) {
      defs.add((key: 'pharmacy', label: l.pharmacies, icon: Icons.local_pharmacy_rounded));
    }
    if (types.contains('lab')) {
      defs.add((key: 'lab', label: l.labs, icon: Icons.science_rounded));
    }
    if (types.contains('optical')) {
      defs.add((key: 'optical', label: l.opticalShops, icon: Icons.remove_red_eye_rounded));
    }
    if (types.contains('clinic')) {
      defs.add((key: 'clinic', label: l.clinics, icon: Icons.medical_services_rounded));
    }
    if (s.allOffers.any((o) => o.category == 'credit')) {
      defs.add((key: 'credit', label: l.mobileCredit, icon: Icons.phone_android_rounded));
    }
    return defs;
  }

  // ── Sections ─────────────────────────────────────────────────────
  Widget _buildHero(BuildContext context, AppLocalizations l) {
    return SliverAppBar(
      expandedHeight: 180.h,
      pinned: true,
      backgroundColor: const Color(0xFF007E80),
      iconTheme: const IconThemeData(color: Colors.white),
      title: Text(
        l.offers,
        style: AppTextStyles.getTitle1(context).copyWith(color: Colors.white),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF007E80), Color(0xFF00B4B6)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Stack(
            children: [
              Positioned(top: -30.r, right: -20.r, child: _decoCircle(120.r, 0.06)),
              Positioned(bottom: -20.r, left: -10.r, child: _decoCircle(80.r, 0.04)),
              Positioned(top: 40.h, left: 60.w, child: _decoCircle(50.r, 0.03)),
              Positioned(
                bottom: 18.h,
                left: 0,
                right: 0,
                child: BlocBuilder<UserCubit, UserState>(
                  builder: (context, userState) {
                    final pts = userState is UserLoaded ? userState.userPoints : 0;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: EdgeInsets.all(10.r),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.stars_rounded,
                              color: const Color(0xFFFFD54F), size: 22.sp),
                        ),
                        SizedBox(height: 6.h),
                        Text(
                          '$pts ${l.points}',
                          style: TextStyle(
                            fontSize: 22.sp,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          l.browseOffersWithPoints,
                          style: AppTextStyles.getText3(context)
                              .copyWith(color: Colors.white.withOpacity(0.8)),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _decoCircle(double size, double opacity) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(opacity),
        ),
      );

  Widget _buildChips(BuildContext context, AppLocalizations l, OffersLoaded s) {
    final defs = _buildChipDefs(l, s);
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 44.h,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
          itemCount: defs.length,
          separatorBuilder: (_, __) => SizedBox(width: 8.w),
          itemBuilder: (_, i) {
            final d = defs[i];
            return CategoryChip(
              label: d.label,
              icon: d.icon,
              isSelected: _activeFilter == d.key,
              onTap: () => setState(() => _activeFilter = d.key),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMegaCarousel(BuildContext context, AppLocalizations l, List<OfferModel> mega) {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 6.h),
            child: Row(
              children: [
                Icon(Icons.local_fire_department_rounded,
                    size: 18.sp, color: const Color(0xFFFF8F00)),
                SizedBox(width: 6.w),
                Text(
                  l.megaOffer,
                  style: AppTextStyles.getTitle3(context).copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.mainDark,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 200.h,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 12.w),
              itemCount: mega.length,
              itemBuilder: (_, i) {
                final o = mega[i];
                return _MegaCarouselCard(
                  offer: o,
                  onTap: () => Navigator.push(
                    context,
                    fadePageRoute(OfferDetailPage(offer: o)),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedPartners(BuildContext context, AppLocalizations l, List<PartnerModel> partners) {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 18.h, 16.w, 6.h),
            child: Text(
              l.featuredPartners,
              style: AppTextStyles.getTitle3(context).copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.mainDark,
              ),
            ),
          ),
          SizedBox(
            height: 100.h,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 14.w),
              itemCount: partners.length,
              separatorBuilder: (_, __) => SizedBox(width: 6.w),
              itemBuilder: (_, i) => PartnerBubble(
                partner: partners[i],
                onTap: () => Navigator.push(
                  context,
                  fadePageRoute(PartnerProfilePage(partnerId: partners[i].id)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfferListHeader(BuildContext context, AppLocalizations l) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16.w, 18.h, 16.w, 6.h),
        child: Text(
          l.allOffersTitle,
          style: AppTextStyles.getTitle3(context).copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.mainDark,
          ),
        ),
      ),
    );
  }

  List<Widget> _buildOfferList(BuildContext context, List<OfferModel> offers) {
    if (offers.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
            child: Center(
              child: Text(
                AppLocalizations.of(context)!.noOffersAvailable,
                style: AppTextStyles.getText2(context).copyWith(color: Colors.grey[500]),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: 24.h)),
      ];
    }
    return [
      SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, i) => OfferCoverCard(
            offer: offers[i],
            index: i,
            onTap: () => Navigator.push(
              context,
              fadePageRoute(OfferDetailPage(offer: offers[i])),
            ),
          ),
          childCount: offers.length,
        ),
      ),
      SliverToBoxAdapter(child: SizedBox(height: 24.h)),
    ];
  }
}

/// Mega carousel card — full-cover image with title + points overlay.
class _MegaCarouselCard extends StatelessWidget {
  final OfferModel offer;
  final VoidCallback onTap;

  const _MegaCarouselCard({required this.offer, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final brand = colorFromHex(offer.partnerBrandColor, fallback: const Color(0xFFFF8F00));

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 280.w,
        margin: EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.h),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18.r),
          boxShadow: [
            BoxShadow(
              color: brand.withOpacity(0.20),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18.r),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (offer.imageUrl != null)
                Image.network(
                  offer.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _gradient(brand),
                )
              else
                _gradient(brand),
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
              PositionedDirectional(
                top: 12.h,
                start: 12.w,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
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
                        l.megaOffer,
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
                bottom: 14.h,
                start: 14.w,
                end: 14.w,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      offer.getLocalizedTitle(locale),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16.sp,
                        height: 1.2,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Row(
                      children: [
                        if (offer.getLocalizedPartnerName(locale) != null)
                          Expanded(
                            child: Text(
                              offer.getLocalizedPartnerName(locale)!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 11.sp,
                              ),
                            ),
                          ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.22),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.stars_rounded, size: 12.sp, color: Colors.white),
                              SizedBox(width: 4.w),
                              Text(
                                '${offer.pointsCost}',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12.sp,
                                ),
                              ),
                            ],
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
      ),
    );
  }

  Widget _gradient(Color brand) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [brand, brand.withOpacity(0.7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      );
}
