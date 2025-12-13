import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';

class HealthRecordCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final List<Widget> tags;
  final VoidCallback? onTap;
  final VoidCallback? onMenu;
  final bool highlighted;
  final Color? highlightColor;

  const HealthRecordCard({
    required this.icon,
    required this.title,
    this.subtitle,
    this.tags = const [],
    this.onTap,
    this.onMenu,
    this.highlighted = false,
    this.highlightColor,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Directionality.of(context) == TextDirection.rtl;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: highlighted
                ? (highlightColor ?? AppColors.main).withOpacity(0.45)
                : AppColors.main.withOpacity(0.12),
            width: 0.9,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
          children: [
            /// ICON
            Container(
              width: 26.w,
              height: 26.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.main.withOpacity(0.12),
              ),
              child: Icon(
                icon,
                size: 16.sp,
                color: AppColors.mainDark,
              ),
            ),

            SizedBox(width: 10.w),

            /// TEXT + TAGS
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// TITLE
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.getTitle1(context).copyWith(
                      fontSize: 11.sp,
                      color: AppColors.blackText,
                    ),
                  ),

                  if (subtitle != null && subtitle!.trim().isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: 3.h),
                      child: Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.getText3(context).copyWith(
                          fontSize: 9.sp,
                          color: AppColors.grayMain,
                        ),
                      ),
                    ),

                  SizedBox(height: 6.h),

                  /// TAGS ROW
                  Wrap(
                    spacing: 6.w,
                    runSpacing: 6.h,
                    children: tags,
                  ),
                ],
              ),
            ),

            SizedBox(width: 8.w),

            /// MENU BUTTON
            if (onMenu != null)
              GestureDetector(
                onTap: onMenu,
                child: Padding(
                  padding: EdgeInsets.only(top: 4.h),
                  child: Icon(
                    Icons.more_vert,
                    size: 20.sp,
                    color: AppColors.mainDark,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
