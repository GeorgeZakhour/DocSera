import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/screens/home/health/widgets/health_primary_button.dart';
import 'package:docsera/screens/home/health/widgets/health_recap_item.dart';

/// ------------------------------------------------------------
/// GENERIC FINAL STEP (RECAP STEP)
/// Works exactly like the old allergy recap step
/// with RTL/LTR support + same spacing + same design
/// ------------------------------------------------------------
class HealthRecapStep extends StatelessWidget {
  /// عناصر الملخص
  final List<RecapItemData> items;

  /// عنوان القسم (ARB)
  final String title;

  /// نص داخل مربع المعلومات (optional)
  final String? infoText;

  /// نص زر الحفظ (ARB)
  final String saveText;

  /// هل الزر في حالة تحميل؟
  final bool loading;

  /// ماذا يحدث عند الضغط على Save
  final VoidCallback onSave;

  const HealthRecapStep({
    super.key,
    required this.items,
    required this.title,
    required this.saveText,
    required this.onSave,
    this.infoText,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Directionality.of(context) == TextDirection.rtl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 10.h),

        /// TITLE
        Text(
          title,
          style: AppTextStyles.getTitle1(context).copyWith(
            fontSize: 14.sp,
            color: AppColors.mainDark,
          ),
        ),

        SizedBox(height: 14.h),

        /// LIST OF ITEMS — using HealthRecapItem (old behavior)
        ...items.map(
              (item) => Padding(
            padding: EdgeInsets.only(bottom: 10.h),
            child: HealthRecapItem(
              title: item.title,
              value: item.value,
            ),
          ),
        ),

        SizedBox(height: 12.h),

        /// INFO BOX (optional)
        if (infoText != null)
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: AppColors.main.withOpacity(0.07),
              border: Border.all(
                color: AppColors.main.withOpacity(0.35),
                width: 1,
              ),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline,
                    size: 16.sp, color: AppColors.main),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    infoText!,
                    textAlign: isArabic ? TextAlign.right : TextAlign.left,
                    style: AppTextStyles.getText3(context).copyWith(
                      fontSize: 11.sp,
                      color: AppColors.mainDark,
                    ),
                  ),
                ),
              ],
            ),
          ),

        const Spacer(),

        /// SAVE BUTTON — same as old code
        HealthPrimaryButton(
          text: saveText,
          loading: loading,
          onTap: loading ? null : onSave,
        ),

        SizedBox(height: 15.h),
      ],
    );
  }
}

/// ------------------------------------------------------------
/// Recap Item Data Model
/// ------------------------------------------------------------
class RecapItemData {
  final String title;
  final String value;

  RecapItemData({
    required this.title,
    required this.value,
  });
}
