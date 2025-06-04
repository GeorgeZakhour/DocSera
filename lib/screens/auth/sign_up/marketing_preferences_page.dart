import 'package:docsera/app/text_styles.dart';
import 'package:docsera/screens/auth/sign_up/validation_page.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'package:docsera/widgets/base_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../../app/const.dart';
import '../../../models/sign_up_info.dart'; // Import the SignUpInfo model

class MarketingPreferencesPage extends StatefulWidget {
  final SignUpInfo signUpInfo; // Accept the SignUpInfo object

  const MarketingPreferencesPage({Key? key, required this.signUpInfo}) : super(key: key);

  @override
  State<MarketingPreferencesPage> createState() => _MarketingPreferencesPageState();
}

class _MarketingPreferencesPageState extends State<MarketingPreferencesPage> {
  bool isChecked = false; // Track the checkbox state

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
            // 🟢 Header Image & Title
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.notifications_active,
                    color: AppColors.main,
                    size: 50.sp,
                  ),
                  SizedBox(height: 10.h),
                  Text(
                    AppLocalizations.of(context)!.marketingPreferencesTitle,
                    style: AppTextStyles.getTitle1(context).copyWith(fontSize: 14.sp),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 5.h),
                  Text(
                    AppLocalizations.of(context)!.marketingPreferencesSubtitle,
                    style: AppTextStyles.getText2(context),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            SizedBox(height: 20.h),

            // 🟢 Marketing Preferences Checkbox
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: CheckboxListTile(
                title: Text(
                  AppLocalizations.of(context)!.marketingCheckboxText,
                  style: AppTextStyles.getText2(context),
                ),
                value: isChecked,
                activeColor: AppColors.main,
                onChanged: (value) {
                  setState(() {
                    isChecked = value ?? false;
                  });
                },
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ),
            SizedBox(height: 10.h),

            // 🟢 Privacy Policy Link
            Wrap(
              alignment: WrapAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.privacyPolicyInfo,
                  style: AppTextStyles.getText3(context),
                ),
                GestureDetector(
                  onTap: () {
                    // TODO: Implement privacy policy navigation
                  },
                  child: Text(
                    AppLocalizations.of(context)!.privacyPolicyLink,
                    style: AppTextStyles.getText3(context).copyWith(
                      color: AppColors.main,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20.h),

            // 🟢 Progress Line
            LinearProgressIndicator(
              value: 0.9,
              backgroundColor: AppColors.main.withOpacity(0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.main),
              minHeight: 4,
            ),
            SizedBox(height: 20.h),

            // 🟢 Continue Button
            ElevatedButton(
              onPressed: () {
                // Update marketingChecked in SignUpInfo
                widget.signUpInfo.marketingChecked = isChecked;

                // Navigate to ValidationPage
                Navigator.push(
                  context,
                  fadePageRoute(ValidationPage(
                    signUpInfo: widget.signUpInfo, // Pass updated SignUpInfo
                    validationType: 'SMS',
                  )),
                );
              },
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: AppColors.main,
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
