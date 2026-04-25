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
import 'package:docsera/utils/page_transitions.dart';
import 'offer_detail_page.dart';
import 'widgets/offer_card.dart';

class OffersPage extends StatefulWidget {
  const OffersPage({super.key});

  @override
  State<OffersPage> createState() => _OffersPageState();
}

class _OffersPageState extends State<OffersPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    context.read<OffersCubit>().loadOffers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
            if (state is OffersLoading) {
              return _buildLoadingScaffold(l);
            }

            if (state is OffersError) {
              return _buildErrorScaffold(l, state.message);
            }

            if (state is OffersLoaded) {
              return _buildContent(l, state);
            }

            return _buildLoadingScaffold(l);
          },
        ),
      ),
    );
  }

  Widget _buildLoadingScaffold(AppLocalizations l) {
    return CustomScrollView(
      slivers: [
        _buildAppBar(l),
        const SliverFillRemaining(
          child: Center(child: CircularProgressIndicator(color: AppColors.main)),
        ),
      ],
    );
  }

  Widget _buildErrorScaffold(AppLocalizations l, String message) {
    return CustomScrollView(
      slivers: [
        _buildAppBar(l),
        SliverFillRemaining(
          child: Center(child: Text(message)),
        ),
      ],
    );
  }

  SliverAppBar _buildAppBar(AppLocalizations l) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: const Color(0xFF007E80),
      systemOverlayStyle: SystemUiOverlayStyle.light,
      iconTheme: const IconThemeData(color: Colors.white),
      title: Text(
        l.offers,
        style: AppTextStyles.getTitle1(context).copyWith(color: Colors.white),
      ),
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(48.h),
        child: _buildTabBar(l),
      ),
    );
  }

  Widget _buildTabBar(AppLocalizations l) {
    return TabBar(
      controller: _tabController,
      indicatorColor: Colors.white,
      indicatorWeight: 3,
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white60,
      labelStyle: AppTextStyles.getText2(context).copyWith(fontWeight: FontWeight.w700, color: Colors.white),
      unselectedLabelStyle: AppTextStyles.getText2(context).copyWith(fontWeight: FontWeight.w500, color: Colors.white60),
      tabs: [
        Tab(text: l.all),
        Tab(text: l.healthPartners),
        Tab(text: l.mobileCredit),
      ],
    );
  }

  Widget _buildContent(AppLocalizations l, OffersLoaded state) {
    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return [
          _buildAppBar(l),
          // Points balance mini bar
          SliverToBoxAdapter(
            child: BlocBuilder<UserCubit, UserState>(
              builder: (context, userState) {
                if (userState is! UserLoaded) return const SizedBox();
                return Container(
                  margin: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 6.h),
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.main.withOpacity(0.08),
                        AppColors.main.withOpacity(0.03),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: AppColors.main.withOpacity(0.12)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.stars_rounded, color: AppColors.main, size: 18.sp),
                      SizedBox(width: 8.w),
                      Text(
                        l.yourPoints,
                        style: AppTextStyles.getText3(context).copyWith(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${userState.userPoints}',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w800,
                          color: AppColors.main,
                        ),
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        l.points,
                        style: AppTextStyles.getText3(context).copyWith(
                          color: AppColors.main.withOpacity(0.6),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          // Featured mega offers horizontal scroll
          if (state.allOffers.any((o) => o.isMegaOffer))
            SliverToBoxAdapter(
              child: _buildFeaturedSection(l, state),
            ),
        ];
      },
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOfferList(state.allOffers.where((o) => !o.isMegaOffer).toList()),
          _buildOfferList(state.partnerOffers),
          _buildOfferList(state.creditOffers),
        ],
      ),
    );
  }

  Widget _buildFeaturedSection(AppLocalizations l, OffersLoaded state) {
    final megaOffers = state.allOffers.where((o) => o.isMegaOffer).toList();
    if (megaOffers.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 8.h),
          child: Row(
            children: [
              Icon(Icons.local_fire_department_rounded, size: 18.sp, color: const Color(0xFFFF8F00)),
              SizedBox(width: 6.w),
              Text(
                l.megaOffer,
                style: AppTextStyles.getTitle2(context).copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.mainDark,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 150.h,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            itemCount: megaOffers.length,
            itemBuilder: (context, index) {
              final offer = megaOffers[index];
              final locale = Localizations.localeOf(context).languageCode;
              return _FeaturedOfferCard(
                title: offer.getLocalizedTitle(locale),
                partner: offer.getLocalizedPartnerName(locale) ?? '',
                pointsCost: offer.pointsCost,
                logoUrl: offer.partnerLogoUrl,
                index: index,
                onTap: () => Navigator.push(context, fadePageRoute(OfferDetailPage(offer: offer))),
              );
            },
          ),
        ),
        SizedBox(height: 4.h),
        Divider(color: Colors.grey.withOpacity(0.12), indent: 16.w, endIndent: 16.w),
      ],
    );
  }

  Widget _buildOfferList(List offers) {
    if (offers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(24.w),
              decoration: BoxDecoration(
                color: AppColors.main.withOpacity(0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.local_offer_rounded,
                size: 48.sp,
                color: AppColors.main.withOpacity(0.4),
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              AppLocalizations.of(context)!.noOffersAvailable,
              style: AppTextStyles.getText1(context).copyWith(
                color: Colors.grey[500],
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      itemCount: offers.length,
      itemBuilder: (context, index) {
        final offer = offers[index];
        return OfferCard(
          offer: offer,
          index: index,
          onTap: () => Navigator.push(context, fadePageRoute(OfferDetailPage(offer: offer))),
        );
      },
    );
  }
}

/// Horizontal featured offer card with gradient and animation
class _FeaturedOfferCard extends StatelessWidget {
  final String title;
  final String partner;
  final int pointsCost;
  final String? logoUrl;
  final int index;
  final VoidCallback onTap;

  const _FeaturedOfferCard({
    required this.title,
    required this.partner,
    required this.pointsCost,
    this.logoUrl,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 500 + (index * 100)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(30 * (1 - value), 0),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 250.w,
          margin: EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.h),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF8F00), Color(0xFFFFB300), Color(0xFFFFCA28)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18.r),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF8F00).withOpacity(0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Decorative circle
              Positioned(
                top: -15.r,
                right: -15.r,
                child: Container(
                  width: 70.r,
                  height: 70.r,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.12),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.local_fire_department_rounded, size: 16.sp, color: Colors.white),
                        SizedBox(width: 4.w),
                        Text(
                          AppLocalizations.of(context)!.megaOffer,
                          style: TextStyle(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      title,
                      style: AppTextStyles.getText1(context).copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (partner.isNotEmpty)
                          Expanded(
                            child: Text(
                              partner,
                              style: AppTextStyles.getText3(context).copyWith(
                                color: Colors.white.withOpacity(0.85),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.stars_rounded, size: 12.sp, color: Colors.white),
                              SizedBox(width: 4.w),
                              Text(
                                '$pointsCost',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
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
}
