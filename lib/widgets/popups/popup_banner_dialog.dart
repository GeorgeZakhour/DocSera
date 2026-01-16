import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../app/const.dart';
import 'package:docsera/models/popup_banner_model.dart';
import 'package:docsera/app/text_styles.dart';

class PopupBannerDialog extends StatelessWidget {
  final PopupBannerModel banner;
  final VoidCallback onDismiss;
  final VoidCallback onAction;

  const PopupBannerDialog({
    super.key,
    required this.banner,
    required this.onDismiss,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    // Determine colors based on type
    Color titleColor = AppColors.mainDark;
    Color buttonColor = AppColors.main;
    
    // Logic for specific types if needed in future
    if (banner.type == 'maintenance') {
      // titleColor remains default dark
      buttonColor = AppColors.main; 
    }

    final lang = Localizations.localeOf(context).languageCode;
    final isAsset = banner.imageUrl != null && !banner.imageUrl!.startsWith('http');

    return PopScope(
      canPop: banner.isDismissible,
      child: Dialog(
        backgroundColor: Colors.transparent, // Important for shadow
        insetPadding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 40.h),
        elevation: 0,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Image Logic
                  if (banner.imageUrl != null && banner.imageUrl!.isNotEmpty)
                    isAsset
                        ? Padding(
                            padding: EdgeInsets.only(top: 30.h, bottom: 10.h),
                            child: Center(
                              child: Image.asset(
                                banner.imageUrl!,
                                height: 110.h, // Smaller hero icon
                                width: 110.h,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.grey),
                              ),
                            ),
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
                            child: Image.network(
                              banner.imageUrl!,
                              height: 130.h,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                height: 130.h,
                                color: Colors.grey[200],
                                child: const Icon(Icons.broken_image, color: Colors.grey),
                              ),
                            ),
                          )
                  else
                    SizedBox(height: 30.h),

                  // Content
                  Padding(
                    padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 30.h), // Top padding handled by image/spacer
                    child: Column(
                      children: [
                        Text(
                          banner.getTitle(lang),
                          style: AppTextStyles.getTitle2(context).copyWith( 
                            color: titleColor,
                            fontSize: 18.sp, 
                            height: 1.2,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          banner.getDescription(lang),
                          style: AppTextStyles.getText1(context).copyWith(
                            color: AppColors.grayMain,
                            fontSize: 13.sp,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        
                        if (banner.buttonText.isNotEmpty) ...[
                          SizedBox(height: 24.h),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: onAction,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: buttonColor,
                                padding: EdgeInsets.symmetric(vertical: 12.h),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                              ),
                              child: Text(
                                banner.getButtonText(lang),
                                style: AppTextStyles.getText2(context).copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14.sp,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),

              // Close Button (Floating)
              if (banner.isDismissible)
                Positioned(
                  top: 10.h,
                  right: lang == 'en' ? 10.w : null,
                  left: lang == 'ar' ? 10.w : null,
                  child: Material(
                    color: Colors.black.withOpacity(0.05), // Lighter background for cleaner look on white/image
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onDismiss,
                      child: Padding(
                        padding: EdgeInsets.all(6.sp),
                        child: Icon(
                          Icons.close_rounded,
                          color: AppColors.grayMain, // Darker icon
                          size: 20.sp,
                        ),
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
