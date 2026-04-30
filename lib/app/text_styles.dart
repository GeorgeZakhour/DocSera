import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AppTextStyles {
  /// ✅ **دالة مساعدة لتصغير الخط الإنجليزي فقط دون التأثير على الارتفاع**
  static TextStyle _applyFontScaling(BuildContext context, double fontSize, FontWeight fontWeight) {
    Locale locale = Localizations.localeOf(context);
    bool isArabic = locale.languageCode == 'ar';

    return TextStyle(
      fontSize: isArabic ? fontSize.sp : (fontSize * 0.90).sp, // ✅ تصغير الخط الإنجليزي بنسبة 15%
      fontWeight: fontWeight,
      fontFamily: isArabic ? 'Cairo' : 'Montserrat',
      fontFamilyFallback: isArabic
          ? const ['Montserrat']
          : const ['Cairo'],
    );
  }

  /// 🔹 **العناوين الكبيرة**
  static TextStyle getTitle4(BuildContext context) => _applyFontScaling(context, 32, FontWeight.bold);
  static TextStyle getTitle3(BuildContext context) => _applyFontScaling(context, 20, FontWeight.bold);
  static TextStyle getTitle2(BuildContext context) => _applyFontScaling(context, 16, FontWeight.bold);
  static TextStyle getTitle1(BuildContext context) => _applyFontScaling(context, 12, FontWeight.bold);

  /// 🔹 **النصوص العادية**
  static TextStyle getText1(BuildContext context) => _applyFontScaling(context, 14, FontWeight.normal);
  static TextStyle getText2(BuildContext context) => _applyFontScaling(context, 12, FontWeight.normal);
  static TextStyle getText3(BuildContext context) => _applyFontScaling(context, 10, FontWeight.normal);
  static TextStyle getText4(BuildContext context) => _applyFontScaling(context, 6, FontWeight.bold);
}
