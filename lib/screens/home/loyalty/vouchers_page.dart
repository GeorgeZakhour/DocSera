import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/Business_Logic/Loyalty/vouchers/vouchers_cubit.dart';
import 'package:docsera/Business_Logic/Loyalty/vouchers/vouchers_state.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'voucher_detail_page.dart';
import 'widgets/voucher_card.dart';

class VouchersPage extends StatefulWidget {
  const VouchersPage({super.key});

  @override
  State<VouchersPage> createState() => _VouchersPageState();
}

class _VouchersPageState extends State<VouchersPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    context.read<VouchersCubit>().loadVouchers();
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
          AppLocalizations.of(context)!.myVouchers,
          style: AppTextStyles.getTitle1(context).copyWith(color: Colors.white),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: [
            Tab(text: AppLocalizations.of(context)!.active),
            Tab(text: AppLocalizations.of(context)!.used),
            Tab(text: AppLocalizations.of(context)!.expired),
          ],
        ),
      ),
      body: BlocBuilder<VouchersCubit, VouchersState>(
        builder: (context, state) {
          if (state is VouchersLoading) {
            return const Center(child: CircularProgressIndicator(color: AppColors.main));
          }

          if (state is VouchersLoaded) {
            return TabBarView(
              controller: _tabController,
              children: [
                _buildList(state.active),
                _buildList(state.used),
                _buildList(state.expired),
              ],
            );
          }

          return const SizedBox();
        },
      ),
    );
  }

  Widget _buildList(List vouchers) {
    if (vouchers.isEmpty) {
      return Center(
        child: Text(
          AppLocalizations.of(context)!.noVouchers,
          style: AppTextStyles.getText2(context).copyWith(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(vertical: 12.h),
      itemCount: vouchers.length,
      itemBuilder: (context, index) {
        final voucher = vouchers[index];
        return VoucherCard(
          voucher: voucher,
          onTap: () => Navigator.push(context, fadePageRoute(VoucherDetailPage(voucher: voucher))),
        );
      },
    );
  }
}
