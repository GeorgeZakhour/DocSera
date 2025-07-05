import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/app/const.dart';

class AddImagePreviewSheet extends StatelessWidget {
  final String imagePath;
  final VoidCallback onAdd;


  const AddImagePreviewSheet({
    Key? key,
    required this.imagePath,
    required this.onAdd,
  }) : super(key: key);


  @override
  Widget build(BuildContext context) {
    final isRTL = Directionality.of(context) == TextDirection.rtl;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 16.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ✅ Top Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: isRTL
                    ? [
                  TextButton(
                    onPressed: onAdd,
                    child: Text(
                      AppLocalizations.of(context)!.add,
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: AppColors.main,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.arrow_forward_ios_rounded, size: 16.sp),
                    onPressed: () => Navigator.pop(context),
                  ),
                ]
                    : [
                  IconButton(
                    icon: Icon(Icons.arrow_back, size: 20.sp),
                    onPressed: () => Navigator.pop(context),
                  ),
                  TextButton(
                    onPressed: onAdd,
                    child: Text(
                      AppLocalizations.of(context)!.add,
                      style: TextStyle(
                        fontSize: 16.sp,
                        color: AppColors.main,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.h),

              // ✅ Image with borderRadius and border wrapped nicely
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 15.w),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.main, width: 3),
                    borderRadius: BorderRadius.circular(26.r),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(23.r),
                    child: Image.file(
                      File(imagePath),
                      fit: BoxFit.contain,
                      width: double.infinity,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
