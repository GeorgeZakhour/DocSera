import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/Business_Logic/Account_page/user_cubit.dart';
import 'package:docsera/Business_Logic/Account_page/user_state.dart';
import 'package:docsera/services/supabase/loyalty/loyalty_service.dart';
import 'widgets/points_balance_header.dart';
import 'widgets/transaction_tile.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  List<Map<String, dynamic>> _transactions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background2,
      appBar: AppBar(
        backgroundColor: AppColors.main,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          AppLocalizations.of(context)!.myPoints,
          style: AppTextStyles.getTitle1(context).copyWith(color: Colors.white),
        ),
      ),
      body: BlocBuilder<UserCubit, UserState>(
        builder: (context, state) {
          if (state is! UserLoaded) return const SizedBox();

          return Column(
            children: [
              PointsBalanceHeader(points: state.userPoints),
              SizedBox(height: 16.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    AppLocalizations.of(context)!.transactionHistory,
                    style: AppTextStyles.getTitle1(context).copyWith(color: AppColors.mainDark),
                  ),
                ),
              ),
              SizedBox(height: 8.h),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.main))
                    : _transactions.isEmpty
                        ? Center(
                            child: Text(
                              AppLocalizations.of(context)!.noTransactionsYet,
                              style: AppTextStyles.getText2(context).copyWith(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _transactions.length,
                            itemBuilder: (context, index) {
                              final tx = _transactions[index];
                              return TransactionTile(
                                points: (tx['points'] as num?)?.toInt() ?? 0,
                                description: tx['description'] ?? '—',
                                createdAt: tx['created_at'] ?? '',
                                processed: tx['processed'] as bool? ?? true,
                              );
                            },
                          ),
              ),
            ],
          );
        },
      ),
    );
  }
}
