import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';

class PointsBalanceHeader extends StatefulWidget {
  final int points;

  const PointsBalanceHeader({super.key, required this.points});

  @override
  State<PointsBalanceHeader> createState() => _PointsBalanceHeaderState();
}

class _PointsBalanceHeaderState extends State<PointsBalanceHeader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _countAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _countAnimation = Tween<double>(begin: 0, end: widget.points.toDouble()).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic)),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.5, curve: Curves.easeOut)),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.1, 0.6, curve: Curves.elasticOut)),
    );

    _controller.forward();
  }

  @override
  void didUpdateWidget(PointsBalanceHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.points != widget.points) {
      _countAnimation = Tween<double>(
        begin: oldWidget.points.toDouble(),
        end: widget.points.toDouble(),
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
      _controller.forward(from: 0.3);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showEarnInfo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 32.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            SizedBox(height: 20.h),
            Icon(Icons.emoji_events_rounded, size: 42.sp, color: AppColors.main),
            SizedBox(height: 12.h),
            Text(
              AppLocalizations.of(context)!.earnPointsTitle,
              style: AppTextStyles.getTitle2(context).copyWith(color: AppColors.mainDark),
            ),
            SizedBox(height: 20.h),
            _earnRow(context, Icons.person_add_rounded, AppLocalizations.of(context)!.earnPointsReferral, AppColors.main),
            SizedBox(height: 12.h),
            _earnRow(context, Icons.calendar_today_rounded, AppLocalizations.of(context)!.earnPointsAppointment, const Color(0xFF4CAF50)),
            SizedBox(height: 12.h),
            _earnRow(context, Icons.card_giftcard_rounded, AppLocalizations.of(context)!.earnPointsReferred, const Color(0xFFFF9800)),
            SizedBox(height: 20.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
              decoration: BoxDecoration(
                color: AppColors.main.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: AppColors.main.withOpacity(0.15)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline_rounded, size: 16.sp, color: AppColors.main),
                  SizedBox(width: 8.w),
                  Text(
                    AppLocalizations.of(context)!.pointsValue,
                    style: AppTextStyles.getText2(context).copyWith(
                      color: AppColors.mainDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _earnRow(BuildContext context, IconData icon, String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(icon, color: color, size: 20.sp),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.getText2(context).copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(22.w, 24.h, 22.w, 28.h),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF007E80), Color(0xFF00B4B6), Color(0xFF00C9CB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28.r)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.main.withOpacity(0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.yourPoints,
                      style: AppTextStyles.getText1(context).copyWith(
                        color: Colors.white.withOpacity(0.85),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(width: 6.w),
                    InkWell(
                      onTap: () => _showEarnInfo(context),
                      borderRadius: BorderRadius.circular(20.r),
                      child: Container(
                        padding: EdgeInsets.all(4.w),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.info_outline_rounded,
                          size: 14.sp,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10.h),
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: Text(
                    '${_countAnimation.value.toInt()}',
                    style: TextStyle(
                      fontSize: 48.sp,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.1,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  AppLocalizations.of(context)!.points,
                  style: AppTextStyles.getText2(context).copyWith(
                    color: Colors.white.withOpacity(0.7),
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
