import 'package:docsera/widgets/base_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:url_launcher/url_launcher.dart';

class LegalInformation extends StatelessWidget {
  const LegalInformation({super.key});

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
        AppLocalizations.of(context)!.legalInformation,
        style: AppTextStyles.getTitle1(context).copyWith(color: AppColors.whiteText),
      ),
      child: ListView(
        children: [
          _buildTile(
            context,
            text: AppLocalizations.of(context)!.termsAndConditionsOfUse,
            onTap: () => _launchUrl('https://docsera.app/terms-of-service'),
          ),
          _buildTile(
            context,
            text: AppLocalizations.of(context)!.personalDataProtectionPolicy,
            onTap: () => _launchUrl('https://docsera.app/privacy-policy'),
          ),
          _buildTile(
            context,
            text: AppLocalizations.of(context)!.reportIllicitContent,
            onTap: () => _launchUrl('https://docsera.app/report-illicit-content'),
          ),
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
          title: Text(
            text,
            style: AppTextStyles.getText2(context),
          ),
          trailing: Icon(Icons.open_in_new, size: 14.sp, color: AppColors.main),
          onTap: onTap,
        ),
        Divider(height: 1, color: Colors.grey.shade300),
      ],
    );
  }
}
