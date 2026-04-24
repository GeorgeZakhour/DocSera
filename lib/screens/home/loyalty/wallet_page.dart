import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/Business_Logic/Account_page/user_cubit.dart';
import 'package:docsera/Business_Logic/Account_page/user_state.dart';
import 'package:docsera/services/supabase/loyalty/loyalty_service.dart';
import 'widgets/transaction_tile.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  List<Map<String, dynamic>> _transactions = [];
  bool _loading = true;
  String _filter = 'all'; // all, earned, spent

  late AnimationController _filterController;

  @override
  void initState() {
    super.initState();
    _filterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    WidgetsBinding.instance.addObserver(this);
    _refreshAll();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _filterController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When the app comes back to the foreground, re-check whether pending
    // points have been promoted (the daily cron may have fired while away).
    if (state == AppLifecycleState.resumed) {
      _refreshAll();
    }
  }

  /// Refreshes both the wallet balance (users.points) and the transactions list.
  Future<void> _refreshAll() async {
    // Reload user profile (forces non-cached read so `users.points` is fresh)
    if (mounted) {
      await context.read<UserCubit>().loadUserData(context: context, useCache: false);
    }
    await _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    final userState = context.read<UserCubit>().state;
    if (userState is! UserLoaded) return;

    final history = await LoyaltyService().getPointsHistory(userState.userId);
    if (mounted) {
      setState(() {
        _transactions = history;
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredTransactions {
    if (_filter == 'earned') {
      return _transactions.where((tx) => (tx['points'] as num? ?? 0) > 0).toList();
    } else if (_filter == 'spent') {
      return _transactions.where((tx) => (tx['points'] as num? ?? 0) <= 0).toList();
    }
    return _transactions;
  }

  int get _totalEarned =>
      _transactions.where((tx) => (tx['points'] as num? ?? 0) > 0)
          .fold(0, (sum, tx) => sum + ((tx['points'] as num?)?.toInt() ?? 0));

  int get _totalSpent =>
      _transactions.where((tx) => (tx['points'] as num? ?? 0) < 0)
          .fold(0, (sum, tx) => sum + ((tx['points'] as num?)?.toInt() ?? 0).abs());

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        body: BlocBuilder<UserCubit, UserState>(
          builder: (context, state) {
            if (state is! UserLoaded) return const SizedBox();

            return RefreshIndicator(
              color: AppColors.main,
              onRefresh: () async {
                setState(() => _loading = true);
                // Also re-fetch the user profile so the wallet balance
                // picks up newly-promoted points.
                await _refreshAll();
              },
              child: CustomScrollView(
                slivers: [
                  // Custom SliverAppBar with points
                  SliverAppBar(
                    expandedHeight: 200.h,
                    pinned: true,
                    backgroundColor: const Color(0xFF007E80),
                    systemOverlayStyle: SystemUiOverlayStyle.light,
                    iconTheme: const IconThemeData(color: Colors.white),
                    title: Text(
                      l.myPoints,
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
                            Positioned(
                              top: -30.r,
                              right: -20.r,
                              child: Container(
                                width: 120.r,
                                height: 120.r,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.06),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: -20.r,
                              left: -10.r,
                              child: Container(
                                width: 80.r,
                                height: 80.r,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.04),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 40.h,
                              left: 60.w,
                              child: Container(
                                width: 50.r,
                                height: 50.r,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.03),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 20.h,
                              left: 0,
                              right: 0,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(14.r),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.stars_rounded,
                                      color: const Color(0xFFFFD54F),
                                      size: 28.sp,
                                    ),
                                  ),
                                  SizedBox(height: 10.h),
                                  Text(
                                    '${state.userPoints}',
                                    style: TextStyle(
                                      fontSize: 32.sp,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      height: 1.1,
                                    ),
                                  ),
                                  SizedBox(height: 2.h),
                                  Text(
                                    l.points,
                                    style: AppTextStyles.getText2(context).copyWith(
                                      color: Colors.white.withOpacity(0.75),
                                      fontWeight: FontWeight.w500,
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

                  // Quick stats row
                  if (!_loading && _transactions.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 0),
                        child: Row(
                          children: [
                            Expanded(
                              child: _StatMiniCard(
                                icon: Icons.arrow_upward_rounded,
                                label: l.totalEarned,
                                value: '+$_totalEarned',
                                color: const Color(0xFF4CAF50),
                              ),
                            ),
                            SizedBox(width: 10.w),
                            Expanded(
                              child: _StatMiniCard(
                                icon: Icons.arrow_downward_rounded,
                                label: l.totalSpent,
                                value: '-$_totalSpent',
                                color: const Color(0xFFE53935),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Section title + filter chips
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16.w, 18.h, 16.w, 8.h),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.transactionHistory,
                            style: AppTextStyles.getTitle3(context).copyWith(
                              color: AppColors.mainDark,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 10.h),
                          // Filter chips
                          Row(
                            children: [
                              _FilterChip(
                                label: l.all,
                                isSelected: _filter == 'all',
                                onTap: () => setState(() => _filter = 'all'),
                              ),
                              SizedBox(width: 8.w),
                              _FilterChip(
                                label: l.totalEarned,
                                isSelected: _filter == 'earned',
                                onTap: () => setState(() => _filter = 'earned'),
                                color: const Color(0xFF4CAF50),
                              ),
                              SizedBox(width: 8.w),
                              _FilterChip(
                                label: l.totalSpent,
                                isSelected: _filter == 'spent',
                                onTap: () => setState(() => _filter = 'spent'),
                                color: const Color(0xFFE53935),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Transactions list
                  if (_loading)
                    const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator(color: AppColors.main)),
                    )
                  else if (_filteredTransactions.isEmpty)
                    SliverFillRemaining(
                      child: _buildEmptyState(context),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          if (index == _filteredTransactions.length) {
                            return SizedBox(height: 24.h);
                          }
                          final tx = _filteredTransactions[index];
                          return TransactionTile(
                            transaction: tx,
                            index: index,
                          );
                        },
                        childCount: _filteredTransactions.length + 1,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
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
                Icons.receipt_long_rounded,
                size: 48.sp,
                color: AppColors.main.withOpacity(0.4),
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              AppLocalizations.of(context)!.noTransactionsYet,
              style: AppTextStyles.getText1(context).copyWith(
                color: Colors.grey[500],
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatMiniCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatMiniCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.r),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(icon, color: color, size: 16.sp),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.getText3(context).copyWith(
                    color: Colors.grey[500],
                    fontSize: 10.sp,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? color;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? AppColors.main;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 7.h),
        decoration: BoxDecoration(
          color: isSelected ? chipColor.withOpacity(0.12) : Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: isSelected ? chipColor.withOpacity(0.3) : Colors.grey.withOpacity(0.2),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: chipColor.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: AppTextStyles.getText3(context).copyWith(
            color: isSelected ? chipColor : Colors.grey[600],
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 11.sp,
          ),
        ),
      ),
    );
  }
}
