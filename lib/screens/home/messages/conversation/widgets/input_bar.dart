import 'dart:io';
import 'dart:ui';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class InputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onAddAttachment;
  final bool isEnabled;

  const InputBar({
    Key? key,
    required this.controller,
    required this.onSend,
    required this.onAddAttachment,
    required this.isEnabled,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: 65.h,
          decoration: BoxDecoration(
            color: AppColors.grayMain.withOpacity(0.15),
            border: Border(top: BorderSide(color: Colors.grey.shade300, width: 0.5)),
          ),
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
          child: Row(
            children: [
              GestureDetector(
                onTap: isEnabled ? onAddAttachment : null,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6.w),
                  child: Icon(Icons.add, size: 22.sp, color: AppColors.main),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: isEnabled,
                  style: AppTextStyles.getText3(context).copyWith(fontSize: 12.sp),
                  decoration: InputDecoration(
                    hintText: "اكتب رسالتك...",
                    hintStyle: AppTextStyles.getText3(context).copyWith(
                      fontSize: 11.sp,
                      color: Colors.grey,
                    ),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.85),
                    contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30.r),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              CircleAvatar(
                radius: 18.r,
                backgroundColor: isEnabled ? AppColors.main : Colors.grey,
                child: IconButton(
                  icon: Icon(Icons.send, color: Colors.white, size: 18.sp),
                  onPressed: isEnabled ? onSend : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
