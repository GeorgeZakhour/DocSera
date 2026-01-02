import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;

/// ⚙️ تهيئة المنطقة الزمنية (يُستدعى مرة واحدة في main.dart)
void initializeTimeZonesOnce() {
  tzdata.initializeTimeZones();
}

/// 🕒 Centralized Time Logic for DocSera (Syria Standard)
/// The Single Source of Truth for Time in the App.
class DocSeraTime {
  static final tz.Location _damascus = tz.getLocation('Asia/Damascus');

  // ---------------------------------------------------------------------------
  // 1. GET CURRENT TIME (Sources)
  // ---------------------------------------------------------------------------

  /// ✅ Returns the current time in Syria (UTC+3)
  /// Use this for LOGIC: "Is it today?", "Has the appointment passed?", "Opening hours"
  static tz.TZDateTime nowSyria() {
    return tz.TZDateTime.now(_damascus);
  }

  /// ✅ Returns the current time in UTC
  /// Use this for DATABASE: "created_at", "timestamp", "sending to API"
  static DateTime nowUtc() {
    return DateTime.now().toUtc();
  }

  // ---------------------------------------------------------------------------
  // 2. CONVERSION (Standardization)
  // ---------------------------------------------------------------------------

  /// ✅ Converts any DateTime to Syria Time
  /// Use this for DISPLAY: Showing dates on screen
  static tz.TZDateTime toSyria(DateTime input) {
    // Ensure we start from specific moment in time (UTC)
    final utc = input.isUtc ? input : input.toUtc();
    return tz.TZDateTime.from(utc, _damascus);
  }

  /// ✅ Converts Syria Time back to UTC (if needed for DB)
  static DateTime toUtc(DateTime syriaTime) {
    // If it's already UTC, return it.
    if (syriaTime.isUtc) return syriaTime;
    return syriaTime.toUtc();
  }
  
  /// ✅ Safe Parser: String -> Syria Time
  static tz.TZDateTime? tryParseToSyria(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return null;
    try {
      final utc = DateTime.parse(dateStr).toUtc();
      return tz.TZDateTime.from(utc, _damascus);
    } catch (e) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // 3. FORMATTING (Localized & Standardized)
  // ---------------------------------------------------------------------------

  /// 📅 Formats as "EEEE, d MMMM yyyy" (e.g., "الاثنين، 5 أيار 2026")
  /// Force Syria Time display
  static String formatBusinessDate(BuildContext context, DateTime date) {
    final syriaTime = toSyria(date);
    final locale = Localizations.localeOf(context).toString();
    return DateFormat('EEEE, d MMMM yyyy', locale).format(syriaTime);
  }

  /// ⏰ Formats as "hh:mm a" (e.g., "05:30 م")
  /// Force Syria Time display, with Arabic digits if locale is Arabic
  static String format12hLocalized(BuildContext context, DateTime date) {
    final syriaTime = toSyria(date);
    final bool isArabic = Localizations.localeOf(context).languageCode == 'ar';
    
    final int hour = syriaTime.hour;
    final int displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final String minute = syriaTime.minute.toString().padLeft(2, '0');
    
    final String suffix = isArabic 
        ? (hour >= 12 ? 'م' : 'ص') 
        : (hour >= 12 ? 'PM' : 'AM');
        
    String result = '$displayHour:$minute $suffix';
    
    if (isArabic) {
      const latin = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
      const arabicIndic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
      for (int i = 0; i < 10; i++) {
        result = result.replaceAll(latin[i], arabicIndic[i]);
      }
    }
    
    return result;
  }
  
  /// ✅ Standard 24h format "HH:mm" (Syria Time)
  static String format24h(DateTime date) {
    final syriaTime = toSyria(date);
    final hour = syriaTime.hour.toString().padLeft(2, '0');
    final minute = syriaTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

/// 🔄 Legacy Wrapper for Backward Compatibility
/// (Will be removed after refactor)
class TimezoneUtils {
  static tz.Location get damascus => tz.getLocation('Asia/Damascus');

  static DateTime toDamascus(DateTime input) => DocSeraTime.toSyria(input);
  static DateTime fromDamascusToUtc(DateTime input) => DocSeraTime.toUtc(input);
  static String format12hLocalized(BuildContext context, DateTime input) => DocSeraTime.format12hLocalized(context, input);
  static String format24h(DateTime input) => DocSeraTime.format24h(input);
  
  static String formatBusinessDate(BuildContext context, Map<String, dynamic> appointment) {
    final dateStr = (appointment['appointmentDate'] as String?)?.trim();
    if (dateStr != null && dateStr.isNotEmpty) {
      // Logic from old code: parse dateStr and format
      final d = DateTime.parse(dateStr);
      final locale = Localizations.localeOf(context).toString();
      return DateFormat('EEEE, d MMMM yyyy', locale).format(d);
    }
    // Fallback to timestamp
    final ts = DocSeraTime.tryParseToSyria(appointment['timestamp'].toString()) ?? DocSeraTime.nowSyria();
    return DocSeraTime.formatBusinessDate(context, ts);
  }
}
