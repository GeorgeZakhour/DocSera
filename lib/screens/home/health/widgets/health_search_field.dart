import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/app/const.dart';

class HealthSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final VoidCallback? onClear;

  const HealthSearchField({
    required this.controller,
    required this.hint,
    this.onClear,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Directionality.of(context) == TextDirection.rtl;

    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 12.sp, color: AppColors.grayMain),
        prefixIcon: Icon(Icons.search_rounded, color: AppColors.main, size: 20.sp),
        suffixIcon: controller.text.isNotEmpty
            ? GestureDetector(
          onTap: onClear,
          child: Icon(Icons.close_rounded, color: Colors.grey, size: 18.sp),
        )
            : null,

        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),

        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.r),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.r),
          borderSide: const BorderSide(color: AppColors.main, width: 1.6),
        ),
      ),
    );
  }
}
