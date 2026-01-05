import 'dart:io';
import 'dart:ui';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shimmer/shimmer.dart';

class AttachmentsPreviewBar extends StatelessWidget {
  final List<File> files;
  final String? type; // 'image' or 'pdf'
  final int loadingCount;
  final VoidCallback onClear;

  const AttachmentsPreviewBar({
    super.key,
    required this.files,
    required this.type,
    this.loadingCount = 0,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty && loadingCount == 0) return const SizedBox();

    final isPdf = type == "pdf";
    final local = Localizations.localeOf(context).languageCode;

    /// PDF Preview
    if (isPdf) {
      if (files.isEmpty && loadingCount > 0) {
        // PDF Loading Placeholder
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
                     SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.main),
                     ),
                     SizedBox(width: 10.w),
                     Text("Loading PDF...", style: AppTextStyles.getText2(context).copyWith(fontSize: 12.sp)),
                  ],
                ),
              ),
            ),
          ),
        );
      }
      
      final fileName = files.first.path.split("/").last;
      final shortName =
      fileName.length > 30 ? "${fileName.substring(0, 27)}..." : fileName;

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
    final totalCount = files.length + loadingCount;
    final displayLimit = 4; // Max visible images before overflow

    List<Widget> items = [];

    // 1. Add Files (up to limit)
    for (int i = 0; i < files.length; i++) {
      if (items.length >= displayLimit) break;
      items.add(ClipRRect(
        borderRadius: BorderRadius.circular(6.r),
        child: Image.file(
          files[i],
          width: 40.w,
          height: 40.w,
          fit: BoxFit.cover,
        ),
      ));
    }

    // 2. Add Shimmers (if space remains)
    if (items.length < displayLimit) {
      for (int i = 0; i < loadingCount; i++) {
        if (items.length >= displayLimit) break;
        items.add(ClipRRect(
          borderRadius: BorderRadius.circular(6.r),
          child: Shimmer.fromColors(
            baseColor: Colors.white.withOpacity(0.4),
            highlightColor: Colors.white.withOpacity(0.8),
            child: Container(
              width: 40.w,
              height: 40.w,
              color: Colors.white,
            ),
          ),
        ));
      }
    }

    // 3. Overflow Indicator
    if (totalCount > displayLimit) {
       final remaining = totalCount - displayLimit;
       items.add(Container(
         width: 40.w,
         height: 40.w,
         decoration: BoxDecoration(
           color: Colors.white.withOpacity(0.5),
           borderRadius: BorderRadius.circular(6.r),
           border: Border.all(color: Colors.white, width: 1),
         ),
         child: Center(
           child: Text(
             "+$remaining",
             style: AppTextStyles.getText2(context).copyWith(
               color: AppColors.mainDark,
               fontWeight: FontWeight.bold,
               fontSize: 14.sp,
             ),
           ),
         ),
       ));
    }

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
                  children: items,
                ),
                const Spacer(),
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
