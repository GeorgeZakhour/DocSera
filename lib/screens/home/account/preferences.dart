import 'package:docsera/widgets/base_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';

class MyPreferencesPage extends StatelessWidget {
  const MyPreferencesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: Text(
        AppLocalizations.of(context)!.myPreferences,
                style: AppTextStyles.getTitle1(context).copyWith(color: AppColors.whiteText),
              ),
      child: ListView(
        children: [
          _buildTile(
            context,
            icon: Icons.favorite_border,
            text: AppLocalizations.of(context)!.personalizedServices,
            onTap: () {}, // TODO
          ),
          _buildTile(
            context,
            icon: Icons.auto_graph_outlined,
            text: AppLocalizations.of(context)!.serviceImprovements,
            onTap: () {}, // TODO
          ),
          _buildTile(
            context,
            icon: Icons.location_on_outlined,
            text: AppLocalizations.of(context)!.map,
            onTap: () {}, // TODO
          ),
          _buildTile(
            context,
            icon: Icons.notifications_outlined,
            text: AppLocalizations.of(context)!.notifications,
            onTap: () {}, // TODO
          ),
          _buildTile(
            context,
            icon: Icons.lock_outline,
            text: AppLocalizations.of(context)!.cookieManagement,
            onTap: () {}, // TODO
          ),
        ],
      ),
    );
  }

  Widget _buildTile(BuildContext context,
      {required IconData icon, required String text, required VoidCallback onTap}) {
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: 16.w),
          leading: Icon(icon, color: AppColors.main, size: 18.sp),
          title: Text(
            text,
            style: AppTextStyles.getText2(context),
          ),
          trailing: Icon(Icons.arrow_forward_ios, size: 12.sp, color: Colors.grey),
          onTap: onTap,
        ),
        Divider(height: 1, color: Colors.grey.shade300),
      ],
    );
  }
}
