import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/Business_Logic/Loyalty/offers/offers_cubit.dart';
import 'package:docsera/Business_Logic/Loyalty/offers/offers_state.dart';
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
    return Scaffold(
      backgroundColor: AppColors.background2,
      appBar: AppBar(
        backgroundColor: AppColors.main,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          AppLocalizations.of(context)!.offers,
          style: AppTextStyles.getTitle1(context).copyWith(color: Colors.white),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: [
            Tab(text: AppLocalizations.of(context)!.all),
            Tab(text: AppLocalizations.of(context)!.healthPartners),
            Tab(text: AppLocalizations.of(context)!.mobileCredit),
          ],
        ),
      ),
      body: BlocBuilder<OffersCubit, OffersState>(
        builder: (context, state) {
          if (state is OffersLoading) {
            return const Center(child: CircularProgressIndicator(color: AppColors.main));
          }

          if (state is OffersError) {
            return Center(child: Text(state.message));
          }

          if (state is OffersLoaded) {
            return TabBarView(
              controller: _tabController,
              children: [
                _buildOfferList(state.allOffers),
                _buildOfferList(state.partnerOffers),
                _buildOfferList(state.creditOffers),
              ],
            );
          }

          return const SizedBox();
        },
      ),
    );
  }

  Widget _buildOfferList(List offers) {
    if (offers.isEmpty) {
      return Center(
        child: Text(
          AppLocalizations.of(context)!.noOffersAvailable,
          style: AppTextStyles.getText2(context).copyWith(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(vertical: 12.h),
      itemCount: offers.length,
      itemBuilder: (context, index) {
        final offer = offers[index];
        return OfferCard(
          offer: offer,
          onTap: () => Navigator.push(context, fadePageRoute(OfferDetailPage(offer: offer))),
        );
      },
    );
  }
}
