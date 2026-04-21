import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';

class PointsBalanceHeader extends StatelessWidget {
  final int points;

  const PointsBalanceHeader({super.key, required this.points});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 28.h, horizontal: 22.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.main, Color(0xFF00B4B6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(22.r)),
      ),
      child: Column(
        children: [
          Text(
            AppLocalizations.of(context)!.yourPoints,
            style: AppTextStyles.getText2(context).copyWith(color: Colors.white70),
          ),
          SizedBox(height: 8.h),
          Text(
            '$points',
            style: TextStyle(
              fontSize: 42.sp,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            AppLocalizations.of(context)!.points,
            style: AppTextStyles.getText2(context).copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
