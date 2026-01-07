import 'package:docsera/app/text_styles.dart';
import 'package:docsera/screens/auth/sign_up/marketing_preferences_page.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'package:docsera/widgets/base_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app/const.dart';
import '../../../models/sign_up_info.dart';

class TermsOfUsePage extends StatefulWidget {
  final SignUpInfo signUpInfo;

  const TermsOfUsePage({super.key, required this.signUpInfo});

  @override
  State<TermsOfUsePage> createState() => _TermsOfUsePageState();
}

class _TermsOfUsePageState extends State<TermsOfUsePage> {
  bool isAccepted = false;
  bool showError = false; // ⛔ لإظهار رسالة الخطأ

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.inAppWebView)) {
      debugPrint('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: Text(
        AppLocalizations.of(context)!.signUp,
        style: AppTextStyles.getTitle1(context)
            .copyWith(color: AppColors.whiteText),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🟢 Icon and Header
            Center(
              child: Column(
                children: [
                  Image.asset(
                    'assets/images/terms_icon.png',
                    height: 70.h,
                  ),
                  SizedBox(height: 10.h),
                  Text(
                    AppLocalizations.of(context)!.termsOfUseTitle,
                    style:
                        AppTextStyles.getTitle1(context).copyWith(fontSize: 14.sp),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20.h),

            // 🟢 Terms Description
            Text(
              AppLocalizations.of(context)!.termsOfUseDescription,
              style: AppTextStyles.getText2(context),
            ),
            SizedBox(height: 15.h),

            // 🟢 Checkbox with Label
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                    color: showError && !isAccepted
                        ? Colors.red
                        : Colors.grey),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: CheckboxListTile(
                title: Text(
                  AppLocalizations.of(context)!.acceptTerms,
                  style: AppTextStyles.getText2(context),
                ),
                value: isAccepted,
                activeColor: AppColors.main,
                onChanged: (value) {
                  setState(() {
                    isAccepted = value ?? false;
                    showError = false;
                  });
                },
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ),

            // 🔴 رسالة الخطأ
            if (showError && !isAccepted)
              Padding(
                padding: EdgeInsets.only(top: 5.h, left: 8.w),
                child: Text(
                  AppLocalizations.of(context)!.pleaseAcceptTerms,
                  style: AppTextStyles.getText3(context)
                      .copyWith(color: Colors.red, fontSize: 12.sp),
                ),
              ),

            SizedBox(height: 20.h),

            // 🟢 Data Protection Notice
            Wrap(
              alignment: WrapAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.dataProcessingInfo,
                  style: AppTextStyles.getText3(context),
                ),
                GestureDetector(
                  onTap: () => _launchUrl('https://docsera.app/terms-of-service'),
                  child: Text(
                    AppLocalizations.of(context)!.dataProtectionNotice,
                    style: AppTextStyles.getText3(context).copyWith(
                      color: AppColors.main,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 30.h),

            // 🟢 Progress Line
            LinearProgressIndicator(
              value: 0.8,
              backgroundColor: AppColors.main.withOpacity(0.1),
              valueColor:
              const AlwaysStoppedAnimation<Color>(AppColors.main),
              minHeight: 4,
            ),
            SizedBox(height: 20.h),

            // 🟢 Continue Button
            ElevatedButton(
              onPressed: () {
                if (isAccepted) {
                  Navigator.push(
                    context,
                    fadePageRoute(MarketingPreferencesPage(
                      signUpInfo: widget.signUpInfo..termsAccepted = true,
                    )),
                  );
                } else {
                  setState(() {
                    showError = true;
                  });
                }
              },
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: isAccepted ? AppColors.main : Colors.grey,
                padding: EdgeInsets.symmetric(vertical: 12.h),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: Center(
                  child: Text(
                    AppLocalizations.of(context)!.continueButton,
                    style: AppTextStyles.getText2(context).copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
