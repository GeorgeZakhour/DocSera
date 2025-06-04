import 'package:docsera/models/sign_up_info.dart';
import 'package:docsera/screens/auth/sign_up/sign_up_phone.dart';
import 'package:docsera/screens/auth/login/login_page.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/widgets/base_scaffold.dart';
import 'package:docsera/app/const.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:docsera/app/text_styles.dart';

class IdentificationPage extends StatelessWidget {
  const IdentificationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: Text(
        AppLocalizations.of(context)!.identificationTitle, // ✅ استخدام ARB للعنوان
        style: AppTextStyles.getTitle1(context).copyWith(color: AppColors.whiteText),
      ),
      child: Container(
        color: AppColors.background,
        padding: EdgeInsets.symmetric(horizontal: 20.w), // ✅ استخدام `ScreenUtil`
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(height: 20.h), // ✅ استخدام `ScreenUtil`
            Text(
              AppLocalizations.of(context)!.registerOrLogin, // ✅ استخدام ARB للنص
              style: AppTextStyles.getTitle1(context).copyWith(color: AppColors.blackText),
            ),
            SizedBox(height: 20.h),

            // ✅ زر التسجيل
            _buildContainer(
              context,
              AppLocalizations.of(context)!.newToApp, // ✅ استخدام ARB للنص
              AppLocalizations.of(context)!.signUp, // ✅ استخدام ARB للزر
              AppColors.whiteText,
              AppColors.main,
              SignUpFirstPage(signUpInfo: SignUpInfo()),
            ),

            // ✅ زر تسجيل الدخول
            _buildContainer(
              context,
              AppLocalizations.of(context)!.alreadyHaveAccount, // ✅ استخدام ARB للنص
              AppLocalizations.of(context)!.login, // ✅ استخدام ARB للزر
              AppColors.blackText,
              AppColors.yellow,
              const LogInPage(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContainer(
      BuildContext context,
      String text,
      String buttonText,
      Color buttonTextColor,
      Color buttonColor,
      Widget nextPage,
      ) {
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: 15.h,
        horizontal: 20.w,
      ),
      decoration: BoxDecoration(
        color: AppColors.background2,
        borderRadius: BorderRadius.circular(12.r), // ✅ جعل الحواف ديناميكية
      ),
      margin: EdgeInsets.only(bottom: 20.h),
      child: Column(
        children: [
          Text(
            text,
            style: AppTextStyles.getText2(context).copyWith(fontWeight: FontWeight.bold, color: AppColors.blackText),
          ),
          SizedBox(height: 5.h),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                fadePageRoute(nextPage),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonColor,
              padding: EdgeInsets.symmetric(vertical: 10.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              child: Center(
                child: Text(
                  buttonText,
                  style: AppTextStyles.getTitle1(context).copyWith(fontSize: 13.sp,color: buttonTextColor),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
