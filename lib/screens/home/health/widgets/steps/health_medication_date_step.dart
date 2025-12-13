import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class MedicationDateStep extends StatelessWidget {
  final DateTime? selectedDate;
  final Function(DateTime?) onChanged;
  final VoidCallback onNext;

  const MedicationDateStep({
    super.key,
    required this.selectedDate,
    required this.onChanged,
    required this.onNext,
  });

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? now,
      firstDate: DateTime(1950),
      lastDate: DateTime(now.year + 1),

      /// THEME THE DATE PICKER
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.main,
              onPrimary: Colors.white,
              onSurface: AppColors.mainDark,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.main,
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      onChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    final dateText = selectedDate != null
        ? "${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}"
        : t.medications_step2_date_label; // EX: "Select start date"

    final isArabic = Directionality.of(context) == TextDirection.rtl;

    return Column(
      crossAxisAlignment:CrossAxisAlignment.start,
      children: [
        SizedBox(height: 10.h),

        /// TITLE
        Text(
          t.medications_step2_title, // Ex: "When did you start taking this medication?"
          style: AppTextStyles.getTitle1(context).copyWith(
            fontSize: 14.sp,
            color: AppColors.mainDark,
          ),
          textAlign: isArabic ? TextAlign.right : TextAlign.left,
        ),

        SizedBox(height: 12.h),

        /// DATE SELECTION BUTTON
        GestureDetector(
          onTap: () => _pickDate(context),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
            decoration: BoxDecoration(
              color: AppColors.main.withOpacity(0.08),
              borderRadius: BorderRadius.circular(18.r),
              border: Border.all(
                color: AppColors.main.withOpacity(0.25),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_month_rounded,
                    color: AppColors.main, size: 20.sp),

                SizedBox(width: 10.w),

                Expanded(
                  child: Text(
                    selectedDate == null
                        ? t.medications_step2_date_label // "Select start date"
                        : dateText,
                    style: AppTextStyles.getText2(context).copyWith(
                      color: AppColors.mainDark,
                      fontSize: 12.sp,
                    ),
                  ),
                ),

                Icon(Icons.edit_calendar_rounded,
                    color: AppColors.mainDark.withOpacity(0.7), size: 18.sp),
              ],
            ),
          ),
        ),

        const Spacer(),

        /// NEXT BUTTON
        GestureDetector(
          onTap: selectedDate == null ? null : onNext,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 12.h),
            decoration: BoxDecoration(
              color: selectedDate == null
                  ? AppColors.main.withOpacity(0.35)
                  : AppColors.main,
              borderRadius: BorderRadius.circular(24.r),
            ),
            child: Center(
              child: Text(
                t.continueText,
                style: AppTextStyles.getText2(context).copyWith(
                  color: Colors.white,
                  fontSize: 11.sp,
                ),
              ),
            ),
          ),
        ),

        SizedBox(height: 15.h),
      ],
    );
  }
}
