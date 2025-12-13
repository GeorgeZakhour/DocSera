import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/app/const.dart';

class HealthDeleteConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String deleteText;
  final String cancelText;
  final VoidCallback onConfirm;

  const HealthDeleteConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    required this.deleteText,
    required this.cancelText,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      contentPadding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),

      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title,
              style: AppTextStyles.getTitle2(context),
              textAlign: TextAlign.center),
          SizedBox(height: 12.h),

          Text(
            message,
            style: AppTextStyles.getText2(context),
            textAlign: TextAlign.center,
          ),

          SizedBox(height: 24.h),

          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red,
              padding: EdgeInsets.symmetric(vertical: 12.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.r),
              ),
            ),
            onPressed: onConfirm,
            child: Text(deleteText,
                style: AppTextStyles.getText2(context)
                    .copyWith(color: Colors.white)),
          ),

          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              cancelText,
              style: AppTextStyles.getText2(context).copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.blackText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
