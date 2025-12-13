import 'dart:io';
import 'dart:ui';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AttachmentsPreviewBar extends StatelessWidget {
  final List<File> files;
  final String? type; // 'image' or 'pdf'
  final VoidCallback onClear;

  const AttachmentsPreviewBar({
    Key? key,
    required this.files,
    required this.type,
    required this.onClear,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) return const SizedBox();

    final isPdf = type == "pdf";
    final local = Localizations.localeOf(context).languageCode;

    /// PDF Preview
    if (isPdf) {
      final fileName = files.first.path.split("/").last;
      final shortName =
      fileName.length > 30 ? fileName.substring(0, 27) + "..." : fileName;

      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12.r),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                border: Border.all(color: AppColors.main.withOpacity(0.4)),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Row(
                children: [
                  SvgPicture.asset("assets/icons/pdf-file.svg", width: 26.w),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      shortName,
                      style: AppTextStyles.getText2(context).copyWith(
                        fontSize: 12.sp,
                        color: Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon:
                    Icon(Icons.close, color: AppColors.main, size: 20.sp),
                    onPressed: onClear,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    /// IMAGES Preview
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.r),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              border: Border.all(color: AppColors.main.withOpacity(0.4)),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Row(
              children: [
                Wrap(
                  spacing: 6.w,
                  children: files.take(4).map((f) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(6.r),
                      child: Image.file(
                        f,
                        width: 40.w,
                        height: 40.w,
                        fit: BoxFit.cover,
                      ),
                    );
                  }).toList(),
                ),
                Spacer(),
                IconButton(
                  icon: Icon(Icons.close, color: AppColors.main, size: 20.sp),
                  onPressed: onClear,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
