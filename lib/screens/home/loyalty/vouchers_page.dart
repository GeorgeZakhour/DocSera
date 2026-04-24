import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    final l = AppLocalizations.of(context)!;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        body: BlocBuilder<VouchersCubit, VouchersState>(
          builder: (context, state) {
            return NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverAppBar(
                    pinned: true,
                    backgroundColor: const Color(0xFF007E80),
                    systemOverlayStyle: SystemUiOverlayStyle.light,
                    iconTheme: const IconThemeData(color: Colors.white),
                    title: Text(
                      l.myVouchers,
                      style: AppTextStyles.getTitle1(context).copyWith(color: Colors.white),
                    ),
                    bottom: PreferredSize(
                      preferredSize: Size.fromHeight(48.h),
                      child: TabBar(
                        controller: _tabController,
                        indicatorColor: Colors.white,
                        indicatorWeight: 3,
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.white60,
                        labelStyle: AppTextStyles.getText2(context).copyWith(fontWeight: FontWeight.w700, color: Colors.white),
                        unselectedLabelStyle: AppTextStyles.getText2(context).copyWith(fontWeight: FontWeight.w500, color: Colors.white60),
                        tabs: [
                          _buildTabWithCount(l.active, state is VouchersLoaded ? state.active.length : 0, true),
                          _buildTabWithCount(l.used, state is VouchersLoaded ? state.used.length : 0, false),
                          _buildTabWithCount(l.expired, state is VouchersLoaded ? state.expired.length : 0, false),
                        ],
                      ),
                    ),
                  ),

                  // Summary strip
                  if (state is VouchersLoaded)
                    SliverToBoxAdapter(
                      child: Container(
                        margin: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 4.h),
                        child: Row(
                          children: [
                            _VoucherStatChip(
                              icon: Icons.confirmation_number_rounded,
                              label: '${state.active.length} ${l.active}',
                              color: AppColors.main,
                            ),
                            SizedBox(width: 8.w),
                            _VoucherStatChip(
                              icon: Icons.check_circle_rounded,
                              label: '${state.used.length} ${l.used}',
                              color: const Color(0xFF4CAF50),
                            ),
                            SizedBox(width: 8.w),
                            _VoucherStatChip(
                              icon: Icons.timer_off_rounded,
                              label: '${state.expired.length} ${l.expired}',
                              color: Colors.grey,
                            ),
                          ],
                        ),
                      ),
                    ),
                ];
              },
              body: state is VouchersLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.main))
                  : state is VouchersLoaded
                      ? TabBarView(
                          controller: _tabController,
                          children: [
                            _buildList(state.active),
                            _buildList(state.used),
                            _buildList(state.expired),
                          ],
                        )
                      : const SizedBox(),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTabWithCount(String label, int count, bool isPrimary) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (count > 0) ...[
            SizedBox(width: 6.w),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildList(List vouchers) {
    if (vouchers.isEmpty) {
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
                Icons.confirmation_number_rounded,
                size: 48.sp,
                color: AppColors.main.withOpacity(0.4),
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              AppLocalizations.of(context)!.noVouchers,
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
      itemCount: vouchers.length,
      itemBuilder: (context, index) {
        final voucher = vouchers[index];
        return VoucherCard(
          voucher: voucher,
          index: index,
          onTap: () => Navigator.push(context, fadePageRoute(VoucherDetailPage(voucher: voucher))),
        );
      },
    );
  }
}

class _VoucherStatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _VoucherStatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: color.withOpacity(0.12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 13.sp, color: color),
            SizedBox(width: 4.w),
            Text(
              label,
              style: AppTextStyles.getText3(context).copyWith(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 10.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
