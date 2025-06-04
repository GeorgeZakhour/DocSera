import 'package:docsera/app/text_styles.dart';
import 'package:docsera/screens/auth/sign_up/marketing_preferences_page.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'package:docsera/widgets/base_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../../app/const.dart';
import '../../../models/sign_up_info.dart'; // Import the SignUpInfo model

class TermsOfUsePage extends StatefulWidget {
  final SignUpInfo signUpInfo; // Accept SignUpInfo object

  const TermsOfUsePage({super.key, required this.signUpInfo});

  @override
  State<TermsOfUsePage> createState() => _TermsOfUsePageState();
}

class _TermsOfUsePageState extends State<TermsOfUsePage> {
  bool isAccepted = false; // Track if checkbox is selected

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: Text(
        AppLocalizations.of(context)!.signUp,
        style: AppTextStyles.getTitle1(context).copyWith(color: AppColors.whiteText),
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
                    'assets/images/terms_icon.png', // Ensure this file exists and is added to pubspec.yaml
                    height: 70.h,
                  ),
                  SizedBox(height: 10.h),
                  Text(
                    AppLocalizations.of(context)!.termsOfUseTitle,
                    style: AppTextStyles.getTitle1(context).copyWith(fontSize: 14.sp),
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
                border: Border.all(color: Colors.grey),
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
                  });
                },
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ),
            SizedBox(height: 10.h),

            // 🟢 Data Protection Notice
            Wrap(
              alignment: WrapAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.dataProcessingInfo,
                  style: AppTextStyles.getText3(context),
                ),
                GestureDetector(
                  onTap: () {
                    // TODO: Implement data protection notice navigation
                  },
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
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.main),
              minHeight: 4,
            ),
            SizedBox(height: 20.h),

            // 🟢 Continue Button
            ElevatedButton(
              onPressed: isAccepted
                  ? () {
                Navigator.push(
                  context,
                  fadePageRoute(MarketingPreferencesPage(
                    signUpInfo: widget.signUpInfo..termsAccepted = isAccepted, // Update termsAccepted
                  )),
                );
              }
                  : null, // Disable button if checkbox is not selected
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: isAccepted ? AppColors.main : Colors.grey,
                padding: EdgeInsets.symmetric(vertical: 12.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
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
