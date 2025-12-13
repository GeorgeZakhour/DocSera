import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class MedicationDosageStep extends StatefulWidget {
  final String? dosage;
  final Function(String) onChanged;
  final VoidCallback onNext;

  const MedicationDosageStep({
    super.key,
    required this.dosage,
    required this.onChanged,
    required this.onNext,
  });

  @override
  State<MedicationDosageStep> createState() =>
      _MedicationDosageStepState();
}

class _MedicationDosageStepState extends State<MedicationDosageStep> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.dosage ?? "");
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 10.h),

        Text(
          t.medications_step3_title,
          style: AppTextStyles.getTitle1(context).copyWith(
            fontSize: 14.sp,
            color: AppColors.mainDark,
          ),
        ),

        SizedBox(height: 4.h),

        Text(
          t.medications_step3_optional,
          style: AppTextStyles.getText3(context).copyWith(
            color: AppColors.grayMain,
          ),
        ),

        SizedBox(height: 14.h),

        Text(
          t.medications_step3_example,
          style: AppTextStyles.getText3(context).copyWith(
            color: AppColors.grayMain,
          ),
        ),

        SizedBox(height: 8.h),

        TextField(
          controller: _controller,
          maxLength: 200,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            counterText: "",
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.r),
              borderSide: BorderSide(color: Colors.grey.shade400),
            ),
          ),
          onChanged: widget.onChanged,
        ),

        const Spacer(),

        GestureDetector(
          onTap: widget.onNext,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 12.h),
            decoration: BoxDecoration(
              color: AppColors.main,
              borderRadius: BorderRadius.circular(24.r),
            ),
            child: Center(
              child: Text(
                t.add,
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
