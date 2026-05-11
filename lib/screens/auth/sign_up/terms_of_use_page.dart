import 'package:docsera/app/text_styles.dart';
import 'package:docsera/screens/auth/sign_up/marketing_preferences_page.dart';
import 'package:docsera/services/legal/legal_consent_service.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'package:docsera/widgets/base_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import '../../../app/const.dart';
import '../../../models/sign_up_info.dart';

class TermsOfUsePage extends StatefulWidget {
  final SignUpInfo signUpInfo;

  const TermsOfUsePage({super.key, required this.signUpInfo});

  @override
  State<TermsOfUsePage> createState() => _TermsOfUsePageState();
}

class _TermsOfUsePageState extends State<TermsOfUsePage> {
  bool _acceptTerms = false;
  bool _acceptPrivacy = false;
  bool _acceptMedical = false;
  bool _showError = false;

  // Versions match the manifest at docsera.app/legal/versions.json.
  // Pre-launch baseline: every document is at v1.0. Bump these alongside any
  // document text change so the audit trail records the right version.
  static const _versionPrivacy  = '1.0';
  static const _versionTerms    = '1.0';
  static const _versionMedical  = '1.0';

  bool get _allAccepted => _acceptTerms && _acceptPrivacy && _acceptMedical;

  Future<void> _launchUrl(String documentCode) async {
    final locale = Localizations.localeOf(context).languageCode;
    final uri = Uri.parse(LegalConsentService.urlFor(documentCode, locale));
    if (!await launchUrl(uri, mode: LaunchMode.inAppWebView)) {
      debugPrint('Could not launch $uri');
    }
  }

  /// Persist the accepted versions so the post-auth handler in main.dart
  /// can replay them via rpc_record_legal_consent once auth.uid() exists.
  Future<void> _stagePendingConsents() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pending_legal_consents', jsonEncode({
      LegalDocumentCodes.termsOfService:    _versionTerms,
      LegalDocumentCodes.privacyPolicy:     _versionPrivacy,
      LegalDocumentCodes.medicalDisclaimer: _versionMedical,
    }));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return BaseScaffold(
      title: Text(l.signUp,
          style: AppTextStyles.getTitle1(context).copyWith(color: AppColors.whiteText)),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Column(children: [
              Image.asset('assets/images/terms_icon.webp', height: 70.h),
              SizedBox(height: 10.h),
              Text(l.termsOfUseTitle,
                  style: AppTextStyles.getTitle1(context).copyWith(fontSize: 14.sp)),
            ])),
            SizedBox(height: 20.h),

            Text(l.termsOfUseDescriptionV2, style: AppTextStyles.getText2(context)),
            SizedBox(height: 15.h),

            _consentCheckbox(
              context,
              label: l.acceptTerms,
              value: _acceptTerms,
              docCode: LegalDocumentCodes.termsOfService,
              docLabel: l.termsAndConditionsOfUse,
              onChanged: (v) => setState(() {
                _acceptTerms = v ?? false;
                _showError = false;
              }),
            ),
            SizedBox(height: 10.h),
            _consentCheckbox(
              context,
              label: l.acceptPrivacyPolicy,
              value: _acceptPrivacy,
              docCode: LegalDocumentCodes.privacyPolicy,
              docLabel: l.personalDataProtectionPolicy,
              onChanged: (v) => setState(() {
                _acceptPrivacy = v ?? false;
                _showError = false;
              }),
            ),
            SizedBox(height: 10.h),
            _consentCheckbox(
              context,
              label: l.acceptMedicalDisclaimer,
              value: _acceptMedical,
              docCode: LegalDocumentCodes.medicalDisclaimer,
              docLabel: l.medicalDisclaimer,
              onChanged: (v) => setState(() {
                _acceptMedical = v ?? false;
                _showError = false;
              }),
            ),

            if (_showError && !_allAccepted)
              Padding(
                padding: EdgeInsets.only(top: 10.h, left: 8.w),
                child: Text(l.pleaseAcceptAllDocuments,
                    style: AppTextStyles.getText3(context)
                        .copyWith(color: Colors.red, fontSize: 12.sp)),
              ),

            SizedBox(height: 30.h),
            LinearProgressIndicator(
              value: 0.8,
              backgroundColor: AppColors.main.withValues(alpha: 0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.main),
              minHeight: 4,
            ),
            SizedBox(height: 20.h),

            ElevatedButton(
              onPressed: _allAccepted
                  ? () async {
                      await _stagePendingConsents();
                      if (!mounted) return;
                      Navigator.push(
                        context,
                        fadePageRoute(MarketingPreferencesPage(
                          signUpInfo: widget.signUpInfo..termsAccepted = true,
                        )),
                      );
                    }
                  : () => setState(() => _showError = true),
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: _allAccepted ? AppColors.main : Colors.grey,
                padding: EdgeInsets.symmetric(vertical: 12.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: Center(
                  child: Text(l.continueButton,
                      style: AppTextStyles.getText2(context)
                          .copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
            SizedBox(height: 20.h),
          ],
        ),
      ),
    );
  }

  Widget _consentCheckbox(
    BuildContext context, {
    required String label,
    required bool value,
    required String docCode,
    required String docLabel,
    required ValueChanged<bool?> onChanged,
  }) {
    final hasError = _showError && !value;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: hasError ? Colors.red : Colors.grey),
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CheckboxListTile(
            dense: true,
            title: Text(label, style: AppTextStyles.getText2(context)),
            value: value,
            activeColor: AppColors.main,
            onChanged: onChanged,
            controlAffinity: ListTileControlAffinity.leading,
          ),
          Padding(
            padding: EdgeInsets.only(left: 16.w, right: 16.w, bottom: 10.h),
            child: GestureDetector(
              onTap: () => _launchUrl(docCode),
              child: Text(
                docLabel,
                style: AppTextStyles.getText3(context).copyWith(
                  color: AppColors.main,
                  decoration: TextDecoration.underline,
                  fontSize: 11.sp,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
