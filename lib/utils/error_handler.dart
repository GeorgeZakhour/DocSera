import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class ErrorHandler {
  static String resolve(Object error, {String defaultMessage = "حدث خطأ ما"}) {
    final s = error.toString().toLowerCase();

    // 1. Connection / Socket Errors
    if (error is SocketException ||
        s.contains('socketexception') ||
        s.contains('errno = 8') || // nodename nor servname provided
        s.contains('failed host lookup') ||
        s.contains('connection refused') ||
        s.contains('network is unreachable')) {
      return "لا يوجد اتصال بالإنترنت. يرجى التحقق من الشبكة.";
    }

    if (error is http.ClientException || s.contains('clientexception')) {
      return "تعذر الاتصال بالخادم. يرجى التحقق من الإنترنت.";
    }

    // 2. Timeout
    if (s.contains('timeout')) {
      return "انتهت مهلة الاتصال. يرجى المحاولة مرة أخرى.";
    }

    // 3. Postgrest / Supabase Errors
    if (error is PostgrestException) {
      if (error.code != null) {
        // Handle specific PG codes if needed, e.g. 409 conflict
        // if (error.code == '23505') return "هذا السجل موجود مسبقاً.";
      }
      return "حدث خطأ في الخادم (${error.code ?? 'غير معروف'}).";
    }

    // 4. Default fallback with cleaner message (stripping raw stack)
    if (s.length > 100) {
      // If it's a huge stack trace string, just return default
      return defaultMessage;
    }

    return "$defaultMessage: $s";
  }
}
