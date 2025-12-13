import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';

class HealthPrimaryButton extends StatelessWidget {
  final String text;
  final bool enabled;
  final bool loading;
  final VoidCallback? onTap;

  const HealthPrimaryButton({
    super.key,
    required this.text,
    required this.onTap,
    this.enabled = true,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = enabled && !loading;

    return SizedBox(
      width: double.infinity,
      height: 45.h,
      child: ElevatedButton(
        onPressed: isEnabled ? onTap : null,
        style: ButtonStyle(
          backgroundColor: MaterialStateProperty.resolveWith<Color>(
                (states) {
              if (states.contains(MaterialState.disabled)) {
                return Colors.grey.shade300;
              }
              return AppColors.main;
            },
          ),
          foregroundColor: MaterialStateProperty.all<Color>(Colors.white),
          elevation: MaterialStateProperty.all(0),
          shape: MaterialStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24.r),
            ),
          ),
        ),
        child: loading
            ? SizedBox(
          width: 18.w,
          height: 18.w,
          child: const CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white,
          ),
        )
            : Text(
          text,
          style: AppTextStyles.getText2(context).copyWith(
            fontSize: 12.sp,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
