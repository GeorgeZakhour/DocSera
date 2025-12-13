import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';

class HealthStepHeader extends StatelessWidget {
  final List<String> titles;
  final int step;
  final VoidCallback onBack;

  const HealthStepHeader({
    required this.titles,
    required this.step,
    required this.onBack,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Handle (شريط السحب)
        Container(
          width: 46.w,
          height: 4.h,
          decoration: BoxDecoration(
            color: Colors.grey.shade400,
            borderRadius: BorderRadius.circular(4.r),
          ),
        ),

        SizedBox(height: 14.h),

        // العنوان + زر الرجوع
        Row(
          children: [
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_ios_rounded, size: 18, color: Colors.grey),
            ),
            Expanded(
              child: Text(
                titles[step - 1],
                textAlign: TextAlign.center,
                style: AppTextStyles.getTitle1(context).copyWith(
                  fontSize: 13.sp,
                  color: AppColors.blackText,
                ),
              ),
            ),
            SizedBox(width: 40.w), // موازنة للاتجاه الآخر
          ],
        ),

        SizedBox(height: 10.h),

        // نقاط الخطوات
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(titles.length, (i) {
            final active = (i + 1) == step;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: active ? AppColors.main : Colors.white,
                borderRadius: BorderRadius.circular(18.r),
                border: Border.all(
                  color: active
                      ? AppColors.mainDark.withOpacity(0.8)
                      : AppColors.main.withOpacity(0.25),
                  width: 1.1,
                ),
              ),
              child: Text(
                "${i + 1}",
                style: AppTextStyles.getText3(context).copyWith(
                  fontSize: 11.sp,
                  color: active ? Colors.white : AppColors.blackText,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}
