import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/app/const.dart';

class HealthInfoRow extends StatelessWidget {
  final String title;
  final String value;
  final double titleWidth;

  const HealthInfoRow({
    super.key,
    required this.title,
    required this.value,
    this.titleWidth = 90, // مناسب لكل اللغات
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Directionality.of(context) == TextDirection.rtl;

    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // TITLE
          SizedBox(
            width: titleWidth.w,
            child: Text(
              title,
              textAlign: isArabic ? TextAlign.right : TextAlign.left,
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.blackText,
              ),
            ),
          ),

          // VALUE (EXPANDED)
          Expanded(
            child: Text(
              value,
              textAlign: isArabic ? TextAlign.right : TextAlign.start,
              style: TextStyle(
                fontSize: 11.sp,
                color: Colors.grey.shade700,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
