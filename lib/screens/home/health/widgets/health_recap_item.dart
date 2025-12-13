import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';

class HealthRecapItem extends StatelessWidget {
  final String title;
  final String value;

  const HealthRecapItem({
    super.key,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Directionality.of(context) == TextDirection.rtl;

    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Row(
        mainAxisAlignment:
        isArabic ? MainAxisAlignment.start : MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // TITLE
          SizedBox(
            width: 120.w, // ثابت لموازنة كل العناصر
            child: Text(
              title,
              textAlign: isArabic ? TextAlign.right : TextAlign.left,
              style: AppTextStyles.getText2(context).copyWith(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.blackText,
              ),
            ),
          ),

          // VALUE
          Expanded(
            child: Text(
              value,
              textAlign: isArabic ? TextAlign.right : TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.getText2(context).copyWith(
                fontSize: 12.sp,
                color: AppColors.mainDark,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
