import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';

class AccountBannerCard extends StatelessWidget {
  const AccountBannerCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 16.h, right: 16.w, left: 16.w),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 25.w, horizontal: 20.w),
        decoration: BoxDecoration(
          color: AppColors.main.withValues(alpha: 0.05), // Using withValues as withOpacity is deprecated
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Row(
          children: [
            Image.asset(
              'assets/images/account_banner.webp',
              width: 45.w,
              height: 45.w,
            ),
            SizedBox(width: 18.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.accountPrivacyInfoLine1,
                    style: AppTextStyles.getText2(context).copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.blackText,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    AppLocalizations.of(context)!.accountPrivacyInfoLine2,
                    style: AppTextStyles.getText3(context).copyWith(
                      color: AppColors.blackText,
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
}
