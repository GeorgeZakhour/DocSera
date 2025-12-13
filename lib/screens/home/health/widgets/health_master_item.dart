import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';

class HealthMasterTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool disabled;
  final bool selected;
  final String? badgeText;
  final IconData icon;
  final VoidCallback? onTap;

  const HealthMasterTile({
    super.key,
    required this.title,
    required this.icon,
    this.subtitle,
    this.disabled = false,
    this.selected = false,
    this.badgeText,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Directionality.of(context) == TextDirection.rtl;

    // ألوان الحالة
    final Color borderColor = disabled
        ? Colors.grey.shade400
        : selected
        ? AppColors.main
        : AppColors.main.withOpacity(0.15);

    final Color bgColor = disabled
        ? Colors.grey.withOpacity(0.2)
        : selected
        ? AppColors.main.withOpacity(0.08)
        : Colors.white;

    final Color textColor = disabled
        ? Colors.grey.shade600
        : AppColors.blackText;

    final Color iconColor = disabled
        ? Colors.grey.shade500
        : AppColors.mainDark;

    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Directionality(
        textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: Container(
          padding: EdgeInsets.all(12.w),
          margin: EdgeInsets.only(bottom: 8.h),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: borderColor),
            boxShadow: [
              if (!disabled)
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ICON
              Container(
                width: 32.w,
                height: 32.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: disabled
                      ? iconColor.withOpacity(0.15)
                      : AppColors.main.withOpacity(0.12),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 20.sp,
                ),
              ),

              SizedBox(width: 8.w),

              // TEXT CONTENT
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      textAlign: isArabic ? TextAlign.right : TextAlign.left,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.getTitle1(context).copyWith(
                        fontSize: 13.sp,
                        color: textColor,
                      ),
                    ),

                    if (subtitle != null && subtitle!.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: 4.h),
                        child: Text(
                          subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: isArabic ? TextAlign.right : TextAlign.left,
                          style: AppTextStyles.getText3(context).copyWith(
                            fontSize: 11.sp,
                            color: disabled ? Colors.grey.shade600 : AppColors.grayMain,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // BADGE (إذا كان العنصر disabled)
              if (disabled && badgeText != null)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade500.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Text(
                    badgeText!,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w600,
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
