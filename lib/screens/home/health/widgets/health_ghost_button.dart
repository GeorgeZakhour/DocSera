import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';

class HealthGhostButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const HealthGhostButton({
    super.key,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: onTap,
        child: Text(
          text,
          style: AppTextStyles.getText3(context).copyWith(
            color: AppColors.main,
            fontSize: 11.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
