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

class _ReferralSectionPageState extends State<ReferralSectionPage>
    with TickerProviderStateMixin {
  late AnimationController _entryController;
  late AnimationController _codeGlowController;
  bool _codeCopied = false;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _codeGlowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _entryController.forward();
    context.read<ReferralCubit>().loadReferralInfo();
  }

  @override
  void dispose() {
    _entryController.dispose();
    _codeGlowController.dispose();
    super.dispose();
  }

  void _copyCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    HapticFeedback.mediumImpact();
    setState(() => _codeCopied = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.codeCopied),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
        backgroundColor: AppColors.main,
        duration: const Duration(seconds: 2),
      ),
    );
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _codeCopied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        body: BlocBuilder<ReferralCubit, ReferralState>(
          builder: (context, state) {
            if (state is ReferralLoading) {
              return CustomScrollView(
                slivers: [
                  _buildAppBar(l),
                  const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator(color: AppColors.main)),
                  ),
                ],
              );
            }

            if (state is ReferralError) {
              return CustomScrollView(
                slivers: [
                  _buildAppBar(l),
                  SliverFillRemaining(child: Center(child: Text(state.message))),
                ],
              );
            }

            if (state is ReferralLoaded) {
              return _buildContent(l, state);
            }

            return const SizedBox();
          },
        ),
      ),
    );
  }

  SliverAppBar _buildAppBar(AppLocalizations l) {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 160.h,
      backgroundColor: const Color(0xFF007E80),
      systemOverlayStyle: SystemUiOverlayStyle.light,
      iconTheme: const IconThemeData(color: Colors.white),
      title: Text(
        l.referFriends,
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
                bottom: 20.h,
                left: 20.w,
                right: 20.w,
                child: Text(
                  l.referralReward,
                  style: AppTextStyles.getText2(context).copyWith(
                    color: Colors.white.withOpacity(0.8),
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(AppLocalizations l, ReferralLoaded state) {
    return CustomScrollView(
      slivers: [
        _buildAppBar(l),

        // Referral code card
        SliverToBoxAdapter(
          child: _AnimatedEntry(
            controller: _entryController,
            delay: 0.0,
            child: _buildReferralCodeCard(l, state),
          ),
        ),

        // Stats
        SliverToBoxAdapter(
          child: _AnimatedEntry(
            controller: _entryController,
            delay: 0.1,
            child: _buildStatsRow(l, state),
          ),
        ),

        // How it works
        SliverToBoxAdapter(
          child: _AnimatedEntry(
            controller: _entryController,
            delay: 0.2,
            child: _buildHowItWorks(l),
          ),
        ),

        // Recent referrals
        if (state.info.recentReferrals.isNotEmpty)
          SliverToBoxAdapter(
            child: _AnimatedEntry(
              controller: _entryController,
              delay: 0.3,
              child: _buildRecentReferrals(l, state),
            ),
          ),

        SliverToBoxAdapter(child: SizedBox(height: 24.h)),
      ],
    );
  }

  Widget _buildReferralCodeCard(AppLocalizations l, ReferralLoaded state) {
    return Container(
      margin: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 12.h),
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: AppColors.main.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Gift icon
          Container(
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.main.withOpacity(0.12), AppColors.main.withOpacity(0.04)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.card_giftcard_rounded, size: 30.sp, color: AppColors.main),
          ),
          SizedBox(height: 12.h),
          Text(
            l.yourReferralCode,
            style: AppTextStyles.getText2(context).copyWith(color: Colors.grey[500]),
          ),
          SizedBox(height: 12.h),

          // Code with animated glow border
          AnimatedBuilder(
            animation: _codeGlowController,
            builder: (context, child) {
              return GestureDetector(
                onTap: () => _copyCode(state.info.referralCode),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 14.h),
                  decoration: BoxDecoration(
                    color: AppColors.main.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(14.r),
                    border: Border.all(
                      color: AppColors.main.withOpacity(0.15 + 0.1 * _codeGlowController.value),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.main.withOpacity(0.05 * _codeGlowController.value),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        state.info.referralCode,
                        style: TextStyle(
                          fontSize: 24.sp,
                          fontWeight: FontWeight.w800,
                          color: AppColors.main,
                          letterSpacing: 4,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: _codeCopied
                            ? Icon(Icons.check_rounded, key: const ValueKey('check'), size: 20.sp, color: const Color(0xFF4CAF50))
                            : Icon(Icons.copy_rounded, key: const ValueKey('copy'), size: 18.sp, color: AppColors.main.withOpacity(0.5)),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          SizedBox(height: 6.h),
          Text(
            l.tapToCopy,
            style: AppTextStyles.getText3(context).copyWith(color: Colors.grey[400]),
          ),
          SizedBox(height: 16.h),

          // Share button with gradient
          Builder(
            builder: (context) => GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              final box = context.findRenderObject() as RenderBox?;
              final sharePositionOrigin = box != null
                  ? box.localToGlobal(Offset.zero) & box.size
                  : null;
              Share.share(
                l.referralShareMessage(state.info.referralCode),
                sharePositionOrigin: sharePositionOrigin,
              );
            },
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 14.h),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF007E80), Color(0xFF00B4B6)],
                ),
                borderRadius: BorderRadius.circular(14.r),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.main.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.share_rounded, color: Colors.white, size: 18.sp),
                  SizedBox(width: 8.w),
                  Text(
                    l.shareWithFriends,
                    style: AppTextStyles.getText1(context).copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(AppLocalizations l, ReferralLoaded state) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Row(
        children: [
          Expanded(
            child: _AnimatedStatCard(
              icon: Icons.people_rounded,
              value: '${state.info.totalReferrals}',
              label: l.totalReferrals,
              color: AppColors.main,
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: _AnimatedStatCard(
              icon: Icons.stars_rounded,
              value: '${state.info.totalPointsEarned}',
              label: l.pointsEarned,
              color: const Color(0xFFFF9800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHowItWorks(AppLocalizations l) {
    return Container(
      margin: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 0),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_rounded, size: 18.sp, color: const Color(0xFFFF9800)),
              SizedBox(width: 8.w),
              Text(
                l.howItWorks,
                style: AppTextStyles.getText2(context).copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.mainDark,
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          _StepRow(number: 1, text: l.referStep1, icon: Icons.share_rounded, color: AppColors.main),
          _StepConnector(),
          _StepRow(number: 2, text: l.referStep2, icon: Icons.person_add_rounded, color: const Color(0xFF4CAF50)),
          _StepConnector(),
          _StepRow(number: 3, text: l.referStep3, icon: Icons.stars_rounded, color: const Color(0xFFFF9800)),
        ],
      ),
    );
  }

  Widget _buildRecentReferrals(AppLocalizations l, ReferralLoaded state) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.recentReferrals,
            style: AppTextStyles.getTitle2(context).copyWith(
              color: AppColors.mainDark,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 10.h),
          ...state.info.recentReferrals.asMap().entries.map((entry) {
            final index = entry.key;
            final ref = entry.value;
            String date;
            try {
              date = DateFormat('dd MMM yyyy').format(DateTime.parse(ref.completedAt!).toLocal());
            } catch (_) {
              date = '—';
            }
            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: Duration(milliseconds: 400 + (index * 80)),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(0, 20 * (1 - value)),
                  child: Opacity(opacity: value, child: child),
                );
              },
              child: Container(
                margin: EdgeInsets.only(bottom: 8.h),
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
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
                child: Row(
                  children: [
                    Container(
                      width: 38.r,
                      height: 38.r,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.main.withOpacity(0.12), AppColors.main.withOpacity(0.04)],
                        ),
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Icon(Icons.person_add_rounded, size: 16.sp, color: AppColors.main),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ref.referredName ?? "—",
                            style: AppTextStyles.getText2(context).copyWith(fontWeight: FontWeight.w700),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            date,
                            style: AppTextStyles.getText3(context).copyWith(
                              color: Colors.grey[500],
                              fontSize: 10.sp,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: AppColors.main.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        '+${ref.pointsAwarded}',
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w800,
                          color: AppColors.main,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Animated entry wrapper with staggered delay
class _AnimatedEntry extends StatelessWidget {
  final AnimationController controller;
  final double delay;
  final Widget child;

  const _AnimatedEntry({
    required this.controller,
    required this.delay,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final animation = CurvedAnimation(
      parent: controller,
      curve: Interval(delay, (delay + 0.5).clamp(0, 1), curve: Curves.easeOutCubic),
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - animation.value)),
          child: Opacity(
            opacity: animation.value.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// Stat card with animated count-up
class _AnimatedStatCard extends StatefulWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _AnimatedStatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  State<_AnimatedStatCard> createState() => _AnimatedStatCardState();
}

class _AnimatedStatCardState extends State<_AnimatedStatCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _countController;
  late Animation<double> _countAnimation;

  @override
  void initState() {
    super.initState();
    final numValue = int.tryParse(widget.value) ?? 0;
    _countController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _countAnimation = Tween<double>(begin: 0, end: numValue.toDouble()).animate(
      CurvedAnimation(parent: _countController, curve: Curves.easeOutCubic),
    );
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _countController.forward();
    });
  }

  @override
  void dispose() {
    _countController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 14.w),
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
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: widget.color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(widget.icon, color: widget.color, size: 20.sp),
          ),
          SizedBox(height: 10.h),
          AnimatedBuilder(
            animation: _countController,
            builder: (context, _) {
              return Text(
                '${_countAnimation.value.toInt()}',
                style: TextStyle(
                  fontSize: 24.sp,
                  fontWeight: FontWeight.w800,
                  color: widget.color,
                ),
              );
            },
          ),
          SizedBox(height: 4.h),
          Text(
            widget.label,
            style: AppTextStyles.getText3(context).copyWith(color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Step row in "How it works"
class _StepRow extends StatelessWidget {
  final int number;
  final String text;
  final IconData icon;
  final Color color;

  const _StepRow({
    required this.number,
    required this.text,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32.r,
          height: 32.r,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withOpacity(0.7)],
            ),
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Icon(icon, size: 16.sp, color: Colors.white),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.getText2(context).copyWith(
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
        ),
      ],
    );
  }
}

/// Vertical connector between steps
class _StepConnector extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.only(start: 15.r),
      child: Container(
        width: 2,
        height: 16.h,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.grey.withOpacity(0.2), Colors.grey.withOpacity(0.05)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      ),
    );
  }
}
