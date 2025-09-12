import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// 🔄 تحويل UTC → توقيت سوريا (UTC+3)
DateTime toSyriaTime(DateTime utc) => utc.toUtc().add(const Duration(hours: 3));

/// 🕒 تنسيق الوقت 12h حسب اللغة مع دعم أرقام عربية
String format12hLocalized(BuildContext context, DateTime utc) {
  final DateTime local = toSyriaTime(utc);
  final int hour = local.hour;
  final int minute = local.minute;

  final bool isArabic = Localizations.localeOf(context).languageCode == 'ar';
  final bool isPM = hour >= 12;

  int displayHour = hour % 12;
  if (displayHour == 0) displayHour = 12;

  String minuteStr = minute.toString().padLeft(2, '0');
  String suffix = isArabic ? (isPM ? 'م' : 'ص') : (isPM ? 'PM' : 'AM');

  String result = '$displayHour:$minuteStr $suffix';

  if (isArabic) {
    const latin = ['0','1','2','3','4','5','6','7','8','9'];
    const arabicIndic = ['٠','١','٢','٣','٤','٥','٦','٧','٨','٩'];
    for (int i = 0; i < 10; i++) {
      result = result.replaceAll(latin[i], arabicIndic[i]);
    }
  }

  return result;
}

/// 📅 تنسيق التاريخ مثل "الأحد، 5 مايو 2025"
String formatBusinessDate(BuildContext context, Map<String, dynamic> appointment) {
  final locale = Localizations.localeOf(context).toString();

  final dateStr = (appointment['appointmentDate'] as String?)?.trim();
  if (dateStr != null && dateStr.isNotEmpty) {
    final d = DateTime.parse(dateStr); // YYYY-MM-DD
    return DateFormat('EEEE, d MMMM yyyy', locale).format(d);
  }

  // fallback: من timestamp +3
  final tsUtc = DateTime.parse(appointment['timestamp'].toString()).toUtc();
  final biz = tsUtc.add(const Duration(hours: 3));
  final d = DateTime(biz.year, biz.month, biz.day);
  return DateFormat('EEEE, d MMMM yyyy', locale).format(d);
}
