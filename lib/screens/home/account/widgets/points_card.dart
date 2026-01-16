import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/screens/home/account/points_history_page.dart';
import 'package:docsera/utils/page_transitions.dart';

class PointsCard extends StatelessWidget {
  final int userPoints;
  final String userId;

  const PointsCard({
    super.key,
    required this.userPoints,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12.r),
      onTap: () {
        Navigator.push(
          context,
          fadePageRoute(PointsHistoryPage(userId: userId)),
        );
      },
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        child: Container(
          padding: EdgeInsets.all(18.w),
          decoration: BoxDecoration(
            color: AppColors.main.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(
              color: AppColors.main.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: AppColors.main.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.stars, color: AppColors.main, size: 18.sp),
              ),
              SizedBox(width: 14.w),

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.rewardPoints,
                    style: AppTextStyles.getTitle1(context)
                        .copyWith(color: AppColors.mainDark),
                  ),
                  SizedBox(height: 4.h),

                  Text(
                    "$userPoints ${AppLocalizations.of(context)!.points}",
                    style: AppTextStyles.getText2(context)
                        .copyWith(color: AppColors.main),
                  ),
                ],
              ),

              const Spacer(),

              Icon(Icons.arrow_forward_ios, size: 14.sp, color: AppColors.main),
            ],
          ),
        ),
      ),
    );
  }
}
