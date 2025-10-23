import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;

/// ⚙️ تهيئة المنطقة الزمنية (يُستدعى مرة واحدة في main.dart)
void initializeTimeZonesOnce() {
  tzdata.initializeTimeZones();
}

/// 🕓 كلاس أدوات الزمن لتوقيت دمشق (Asia/Damascus)
class TimezoneUtils {
  static final tz.Location damascus = tz.getLocation('Asia/Damascus');

  /// ✅ تحويل أي وقت من UTC إلى توقيت دمشق
  static DateTime toDamascus(DateTime utcTime) {
    if (!utcTime.isUtc) utcTime = utcTime.toUtc();
    return tz.TZDateTime.from(utcTime, damascus);
  }

  /// ✅ تحويل وقت دمشق إلى UTC قبل الحفظ في Supabase
  static DateTime fromDamascusToUtc(DateTime damascusTime) {
    if (damascusTime.isUtc) return damascusTime;
    final tzTime = tz.TZDateTime.from(damascusTime, damascus);
    return tzTime.toUtc();
  }

  /// ✅ فقط للعرض كنص 12 ساعة (مع دعم العربية)
  static String format12hLocalized(BuildContext context, DateTime utcTime) {
    final local = toDamascus(utcTime);
    final bool isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final bool isPM = local.hour >= 12;

    int displayHour = local.hour % 12;
    if (displayHour == 0) displayHour = 12;

    final minuteStr = local.minute.toString().padLeft(2, '0');
    final suffix = isArabic ? (isPM ? 'م' : 'ص') : (isPM ? 'PM' : 'AM');

    String result = '$displayHour:$minuteStr $suffix';

    if (isArabic) {
      const latin = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
      const arabicIndic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
      for (int i = 0; i < 10; i++) {
        result = result.replaceAll(latin[i], arabicIndic[i]);
      }
    }

    return result;
  }

  /// 📅 تنسيق التاريخ مثل "الأحد، 5 مايو 2025"
  static String formatBusinessDate(
      BuildContext context,
      Map<String, dynamic> appointment,
      ) {
    final locale = Localizations.localeOf(context).toString();
    final dateStr = (appointment['appointmentDate'] as String?)?.trim();

    if (dateStr != null && dateStr.isNotEmpty) {
      final d = DateTime.parse(dateStr);
      return DateFormat('EEEE, d MMMM yyyy', locale).format(d);
    }

    // fallback: من timestamp (UTC) → توقيت دمشق
    final tsUtc = DateTime.parse(appointment['timestamp'].toString()).toUtc();
    final damascusTime = toDamascus(tsUtc);
    final d = DateTime(damascusTime.year, damascusTime.month, damascusTime.day);
    return DateFormat('EEEE, d MMMM yyyy', locale).format(d);
  }

  /// ✅ فقط للعرض كنص 24 ساعة
  static String format24h(DateTime utcTime) {
    final local = toDamascus(utcTime);
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
