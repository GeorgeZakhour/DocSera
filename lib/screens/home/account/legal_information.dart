import 'package:docsera/services/legal/legal_consent_service.dart';
import 'package:docsera/widgets/base_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:url_launcher/url_launcher.dart';

class LegalInformation extends StatelessWidget {
  const LegalInformation({super.key});

  Future<void> _open(BuildContext context, String docCode) async {
    final locale = Localizations.localeOf(context).languageCode;
    final uri = Uri.parse(LegalConsentService.urlFor(docCode, locale));
    if (!await launchUrl(uri, mode: LaunchMode.inAppWebView)) {
      debugPrint('Could not launch $uri');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return BaseScaffold(
      title: Text(l.legalInformation,
          style: AppTextStyles.getTitle1(context).copyWith(color: AppColors.whiteText)),
      child: ListView(
        children: [
          _buildTile(context,
              text: l.termsAndConditionsOfUse,
              onTap: () => _open(context, LegalDocumentCodes.termsOfService)),
          _buildTile(context,
              text: l.personalDataProtectionPolicy,
              onTap: () => _open(context, LegalDocumentCodes.privacyPolicy)),
          _buildTile(context,
              text: l.medicalDisclaimer,
              onTap: () => _open(context, LegalDocumentCodes.medicalDisclaimer)),
          _buildTile(context,
              text: l.reportIllicitContent,
              onTap: () => _open(context, LegalDocumentCodes.reportIllicitContent)),
        ],
      ),
    );
  }

  Widget _buildTile(BuildContext context,
      {required String text, required VoidCallback onTap}) {
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: 16.w),
          title: Text(text, style: AppTextStyles.getText2(context)),
          trailing: Icon(Icons.open_in_new, size: 14.sp, color: AppColors.main),
          onTap: onTap,
        ),
        Divider(height: 1, color: Colors.grey.shade300),
      ],
    );
  }
}
