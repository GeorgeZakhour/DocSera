import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';

/// Numeric input matching Docsera's standard text-field language:
/// rounded outline border (25.r), gray border in idle, teal border on
/// focus, label + value rendered in the AppTextStyles font (Cairo / Montserrat).
class WizardNumericField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final ValueChanged<int?> onChanged;

  const WizardNumericField({
    super.key,
    required this.controller,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: false),
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: (v) => onChanged(int.tryParse(v)),
      style: AppTextStyles.getText1(context).copyWith(
        color: AppColors.mainDark,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTextStyles.getText2(context).copyWith(
          color: Colors.grey,
        ),
        floatingLabelStyle: AppTextStyles.getText2(context).copyWith(
          color: AppColors.main,
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 18.w,
          vertical: 14.h,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25.r),
          borderSide: const BorderSide(color: Colors.grey),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25.r),
          borderSide: const BorderSide(color: Colors.grey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25.r),
          borderSide: const BorderSide(color: AppColors.main, width: 2),
        ),
      ),
    );
  }
}
