import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/main.dart';

class LanguageSelectionSheet extends StatefulWidget {
  const LanguageSelectionSheet({super.key});

  @override
  State<LanguageSelectionSheet> createState() => _LanguageSelectionSheetState();
}

class _LanguageSelectionSheetState extends State<LanguageSelectionSheet> {
  /// ✅ تغيير اللغة بناءً على اختيار المستخدم
  void _changeLanguage(String languageCode) {
    final myAppState = MyApp.of(context);
    if (myAppState != null) {
      myAppState.changeLanguage(languageCode);
    }

    setState(() {}); // ✅ Refresh UI
    Navigator.pop(context); // ✅ Close the Bottom Sheet
  }

  @override
  Widget build(BuildContext context) {
    String currentLocale = Localizations.localeOf(context).languageCode;
    bool isArabic = currentLocale == 'ar';

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 10.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ✅ Title
            Padding(
              padding: EdgeInsets.symmetric(vertical: 10.h),
              child: Text(
                AppLocalizations.of(context)!.chooseLanguage,
                style: AppTextStyles.getTitle1(context),
              ),
            ),
            const Divider(),

            // ✅ Arabic Option
            ListTile(
              leading: const Icon(Icons.language, color: AppColors.main),
              title: Text(
                "العربية",
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                ),
              ),
              trailing: currentLocale == 'ar'
                  ? const Icon(Icons.check, color: AppColors.main)
                  : null,
              onTap: () {
                if (mounted) {
                  setState(() {
                    _changeLanguage("ar");
                  });
                }
              },
            ),
            Divider(color: Colors.grey[300]),

            // ✅ English Option
            ListTile(
              leading: const Icon(Icons.language, color: AppColors.main),
              title: Text(
                "English",
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Montserrat',
                ),
              ),
              trailing: currentLocale == 'en'
                  ? const Icon(Icons.check, color: AppColors.main)
                  : null,
              onTap: () {
                if (mounted) {
                  setState(() {
                    _changeLanguage("en");
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
