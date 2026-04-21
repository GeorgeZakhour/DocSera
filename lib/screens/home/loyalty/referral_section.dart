// lib/screens/home/loyalty/referral_section.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:share_plus/share_plus.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/Business_Logic/Loyalty/referral/referral_cubit.dart';
import 'package:docsera/Business_Logic/Loyalty/referral/referral_state.dart';
import 'package:intl/intl.dart';

class ReferralSectionPage extends StatefulWidget {
  const ReferralSectionPage({super.key});

  @override
  State<ReferralSectionPage> createState() => _ReferralSectionPageState();
}

class _ReferralSectionPageState extends State<ReferralSectionPage> {
  @override
  void initState() {
    super.initState();
    context.read<ReferralCubit>().loadReferralInfo();
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
          AppLocalizations.of(context)!.referFriends,
          style: AppTextStyles.getTitle1(context).copyWith(color: Colors.white),
        ),
      ),
      body: BlocBuilder<ReferralCubit, ReferralState>(
        builder: (context, state) {
          if (state is ReferralLoading) {
            return const Center(child: CircularProgressIndicator(color: AppColors.main));
          }

          if (state is ReferralError) {
            return Center(child: Text(state.message));
          }

          if (state is ReferralLoaded) {
            return SingleChildScrollView(
              padding: EdgeInsets.all(20.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Referral code card
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(24.w),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16.r),
                      boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 6)],
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.card_giftcard, size: 40.sp, color: AppColors.main),
                        SizedBox(height: 12.h),
                        Text(
                          AppLocalizations.of(context)!.yourReferralCode,
                          style: AppTextStyles.getText2(context).copyWith(color: Colors.grey),
                        ),
                        SizedBox(height: 12.h),
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: state.info.referralCode));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(AppLocalizations.of(context)!.codeCopied)),
                            );
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 14.h),
                            decoration: BoxDecoration(
                              color: AppColors.main.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12.r),
                              border: Border.all(color: AppColors.main.withOpacity(0.3)),
                            ),
                            child: Text(
                              state.info.referralCode,
                              style: TextStyle(
                                fontSize: 26.sp,
                                fontWeight: FontWeight.bold,
                                color: AppColors.main,
                                letterSpacing: 4,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          AppLocalizations.of(context)!.tapToCopy,
                          style: AppTextStyles.getText3(context).copyWith(color: Colors.grey),
                        ),
                        SizedBox(height: 16.h),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _shareCode(state.info.referralCode),
                            icon: const Icon(Icons.share, color: Colors.white),
                            label: Text(
                              AppLocalizations.of(context)!.shareWithFriends,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.main,
                              padding: EdgeInsets.symmetric(vertical: 12.h),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 16.h),

                  // Stats
                  Row(
                    children: [
                      Expanded(
                        child: _statCard(
                          context,
                          '${state.info.totalReferrals}',
                          AppLocalizations.of(context)!.totalReferrals,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: _statCard(
                          context,
                          '${state.info.totalPointsEarned}',
                          AppLocalizations.of(context)!.pointsEarned,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 16.h),

                  // How it works
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.howItWorks,
                          style: AppTextStyles.getText2(context).copyWith(fontWeight: FontWeight.w700),
                        ),
                        SizedBox(height: 8.h),
                        _step(context, '1', AppLocalizations.of(context)!.referStep1),
                        _step(context, '2', AppLocalizations.of(context)!.referStep2),
                        _step(context, '3', AppLocalizations.of(context)!.referStep3),
                      ],
                    ),
                  ),

                  SizedBox(height: 16.h),

                  // Recent referrals
                  if (state.info.recentReferrals.isNotEmpty) ...[
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        AppLocalizations.of(context)!.recentReferrals,
                        style: AppTextStyles.getTitle1(context).copyWith(color: AppColors.mainDark),
                      ),
                    ),
                    SizedBox(height: 8.h),
                    ...state.info.recentReferrals.map((ref) {
                      String date;
                      try {
                        date = DateFormat('dd/MM/yyyy').format(DateTime.parse(ref.completedAt!).toLocal());
                      } catch (_) {
                        date = '—';
                      }
                      return Container(
                        margin: EdgeInsets.only(bottom: 8.h),
                        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.person_add, size: 18.sp, color: AppColors.main),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Text(
                                '${ref.referredName ?? "User"} — $date',
                                style: AppTextStyles.getText2(context),
                              ),
                            ),
                            Text('+${ref.pointsAwarded}', style: AppTextStyles.getTitle1(context).copyWith(color: AppColors.main)),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            );
          }

          return const SizedBox();
        },
      ),
    );
  }

  void _shareCode(String code) {
    final message = AppLocalizations.of(context)!.referralShareMessage(code);
    Share.share(message);
  }

  Widget _statCard(BuildContext context, String value, String label) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        children: [
          Text(value, style: AppTextStyles.getTitle1(context).copyWith(color: AppColors.main, fontSize: 22.sp)),
          SizedBox(height: 4.h),
          Text(label, style: AppTextStyles.getText3(context).copyWith(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _step(BuildContext context, String num, String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20.w,
            height: 20.w,
            decoration: BoxDecoration(color: AppColors.main.withOpacity(0.15), shape: BoxShape.circle),
            child: Center(child: Text(num, style: TextStyle(fontSize: 11.sp, color: AppColors.main, fontWeight: FontWeight.bold))),
          ),
          SizedBox(width: 10.w),
          Expanded(child: Text(text, style: AppTextStyles.getText3(context))),
        ],
      ),
    );
  }
}
