import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/app/const.dart';

class HealthRecordDetailsDialog extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<DetailRow> rows;
  final VoidCallback? onDelete;
  final String deleteText;
  final String closeText;

  const HealthRecordDetailsDialog({
    super.key,
    required this.title,
    required this.icon,
    required this.rows,
    this.onDelete,
    required this.deleteText,
    required this.closeText,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.background3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      contentPadding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),

      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// HEADER: Icon + Title + Delete Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: AppColors.mainDark, size: 18.sp),
                  SizedBox(width: 6.w),
                  Text(
                    title,
                    style: AppTextStyles.getTitle2(context).copyWith(
                      fontSize: 13.sp,
                      color: AppColors.mainDark,
                    ),
                  ),
                ],
              ),

              if (onDelete != null)
                IconButton(
                  icon: Icon(Icons.delete_outline,
                      color: AppColors.red, size: 18.sp),
                  onPressed: onDelete,
                ),
            ],
          ),

          SizedBox(height: 10.h),
          Divider(thickness: 1, color: AppColors.grayMain.withOpacity(0.4)),
          SizedBox(height: 10.h),

          /// DETAILS ROWS
          ...rows.map((r) => Padding(
            padding: EdgeInsets.only(bottom: 10.h),
            child: _buildInfoRow(context, r.title, r.value),
          )),

          SizedBox(height: 16.h),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                closeText,
                style: AppTextStyles.getText2(context).copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.blackText,
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90.w,
          child: Text(
            title,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.blackText,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 11.sp,
              color: Colors.grey.shade700,
            ),
          ),
        ),
      ],
    );
  }
}

class DetailRow {
  final String title;
  final String value;

  DetailRow(this.title, this.value);
}
