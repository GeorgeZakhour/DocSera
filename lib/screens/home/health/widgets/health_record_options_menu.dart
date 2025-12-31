import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';

class HealthRecordOptionsMenu extends StatelessWidget {
  final VoidCallback onShowDetails;
  final VoidCallback onDelete;
  final String showText;
  final String deleteText;

  const HealthRecordOptionsMenu({
    super.key,
    required this.onShowDetails,
    required this.onDelete,
    required this.showText,
    required this.deleteText,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(16.w),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50.w,
            height: 5.h,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(3.r),
            ),
          ),
          SizedBox(height: 16.h),

          ListTile(
            leading: const Icon(Icons.info_outline, color: AppColors.mainDark),
            title: Text(
              showText,
              style: AppTextStyles.getText2(context)
                  .copyWith(fontWeight: FontWeight.w600),
            ),
            onTap: onShowDetails,
          ),

          const Divider(),

          ListTile(
            leading: const Icon(Icons.delete_outline, color: AppColors.red),
            title: Text(
              deleteText,
              style: AppTextStyles.getText2(context)
                  .copyWith(color: AppColors.red, fontWeight: FontWeight.w600),
            ),
            onTap: onDelete,
          ),

          SizedBox(height: 16.h),
        ],
      ),
    );
  }
}
