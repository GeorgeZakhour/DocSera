import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

class ForceUpdateScreen extends StatelessWidget {
  final String storeUrl;
  final String messageEn;
  final String messageAr;

  const ForceUpdateScreen({
    super.key,
    required this.storeUrl,
    required this.messageEn,
    required this.messageAr,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final title = isArabic ? 'تحديث مطلوب' : 'Update Required';
    final body = isArabic ? messageAr : messageEn;
    final cta = isArabic ? 'تحديث الآن' : 'Update Now';

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 28.w),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SvgPicture.asset(
                  'assets/images/DocSera-shape.svg',
                  width: 80.w,
                ),
                SizedBox(height: 24.h),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.getTitle1(context).copyWith(
                    color: AppColors.main,
                  ),
                ),
                SizedBox(height: 12.h),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.getText2(context).copyWith(
                    color: AppColors.grayMain,
                  ),
                ),
                SizedBox(height: 32.h),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.main,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                    ),
                    onPressed: () async {
                      final uri = Uri.tryParse(storeUrl);
                      if (uri != null) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                    child: Text(
                      cta,
                      style: AppTextStyles.getTitle3(context).copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
