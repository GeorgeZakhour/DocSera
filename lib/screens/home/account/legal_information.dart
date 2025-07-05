import 'package:docsera/widgets/base_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';

class LegalInformation extends StatelessWidget {
  const LegalInformation({super.key});

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
            onTap: () {}, // TODO
          ),
          _buildTile(
            context,
            text: AppLocalizations.of(context)!.termsOfUseAgreement,
            onTap: () {}, // TODO
          ),
          _buildTile(
            context,
            text: AppLocalizations.of(context)!.personalDataProtectionPolicy,
            onTap: () {}, // TODO
          ),
          _buildTile(
            context,
            text: AppLocalizations.of(context)!.cookiePolicy,
            onTap: () {}, // TODO
          ),
          _buildTile(
            context,
            text: AppLocalizations.of(context)!.legalNotice,
            onTap: () {}, // TODO
          ),
          _buildTile(
            context,
            text: AppLocalizations.of(context)!.reportIllicitContent,
            onTap: () {}, // TODO
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
