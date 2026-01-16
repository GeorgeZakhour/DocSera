import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/app/const.dart';

class AccountSectionTitle extends StatelessWidget {
  final String title;

  const AccountSectionTitle({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 15.h),
      child: Text(
        title,
        style: AppTextStyles.getTitle1(context).copyWith(
          color: AppColors.mainDark.withValues(alpha: 0.6),
          fontSize: 12,
        ),
      ),
    );
  }
}
