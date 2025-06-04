import 'package:flutter/material.dart';

/// **📌 يحدد اتجاه النص بناءً على أول حرف مدخل**
TextDirection detectTextDirection(String text) {
  if (text.isEmpty) return TextDirection.ltr; // ✅ افتراضيًا LTR إذا كان الحقل فارغًا

  // ✅ تحقق مما إذا كان الحرف الأول عربيًا
  final bool isArabic = RegExp(r'^[\u0600-\u06FF]').hasMatch(text);
  return isArabic ? TextDirection.rtl : TextDirection.ltr;
}

/// **📌 يحدد محاذاة النص بناءً على لغة التطبيق**
TextAlign getTextAlign(BuildContext context) {
  return Localizations.localeOf(context).languageCode == 'ar'
      ? TextAlign.right  // ✅ النص دائماً على اليمين في العربية
      : TextAlign.left;  // ✅ النص دائماً على اليسار في الإنجليزية
}
