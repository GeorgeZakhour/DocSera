import 'package:intl/intl.dart';

class ChatNameUtils {
  static bool isArabic(String text) {
    return RegExp(r'[\u0600-\u06FF]').hasMatch(text);
  }

  static String initials(String name) {
    final ar = isArabic(name);
    final parts = name.trim().split(' ');

    if (ar) {
      final first = parts.first.isNotEmpty ? parts.first[0] : "";
      return first == "ه" ? "هـ" : first;
    }

    final first = parts.isNotEmpty ? parts[0][0] : "";
    final second = parts.length > 1 ? parts[1][0] : "";
    return (first + second).toUpperCase();
  }

  static String dayLabel(DateTime date, String lang) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final msgDay = DateTime(date.year, date.month, date.day);

    if (msgDay == today) return lang == "ar" ? "اليوم" : "Today";
    if (msgDay == yesterday) return lang == "ar" ? "أمس" : "Yesterday";

    return DateFormat("d MMM", lang == "ar" ? "ar" : "en").format(date);
  }

  static String formatReadTime(DateTime date, String lang) {
    return DateFormat("HH:mm", lang == "ar" ? "ar" : "en").format(date);
  }
}
