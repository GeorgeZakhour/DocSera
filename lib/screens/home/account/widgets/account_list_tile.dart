import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';

class AccountListTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool? isVerified;
  final Widget? trailingWidget;
  final bool isFaceId;

  const AccountListTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.isVerified,
    this.trailingWidget,
    this.isFaceId = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 20.w),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Transform.translate(
              offset: Offset(0, -10.h),
              child: isFaceId && icon == Icons.face
                  ? SvgPicture.asset(
                'assets/icons/face-id.svg',
                width: 20.w,
                height: 20.w,
                colorFilter: const ColorFilter.mode(AppColors.main, BlendMode.srcIn),
              )
                  : Icon(icon, color: AppColors.main, size: 16.sp),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.getText2(context).copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.6,
                    ),
                    child: Text(
                      subtitle,
                      style: AppTextStyles.getText2(context)
                          .copyWith(color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
            if (isVerified != null)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: isVerified!
                      ? AppColors.main.withValues(alpha: 0.1)
                      : AppColors.yellow.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  isVerified!
                      ? AppLocalizations.of(context)!.verified
                      : AppLocalizations.of(context)!.notVerified,
                  style: AppTextStyles.getText3(context).copyWith(
                    color: isVerified! ? AppColors.main : AppColors.yellow,
                    fontWeight: FontWeight.w400,
                    fontSize: 8,
                  ),
                ),
              ),
            if (trailingWidget != null)
              trailingWidget!
            else
              Row(
                children: [
                  SizedBox(width: 8.w),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 12.sp,
                    color: Colors.grey,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
