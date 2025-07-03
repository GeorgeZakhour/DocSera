import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseOTPService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// **إرسال رمز OTP إلى رقم الهاتف**
  Future<String> sendOTPToPhone(String phoneNumber) async {
    try {
      final otp = _generateOTP();
      final expiresAt = DateTime.now().add(const Duration(minutes: 5));

      await _supabase.from('otp').upsert({
        'phone': phoneNumber,
        'otp': otp,
        'expires_at': expiresAt.toIso8601String(),
      });

      print('📱 OTP sent to phone: $phoneNumber, Code: $otp');

      return otp;
    } catch (e) {
      throw Exception('Failed to send OTP to phone: $e');
    }
  }

  /// **إرسال رمز OTP إلى البريد الإلكتروني**
  Future<String> sendOTPToEmail(String email) async {
    try {
      final otp = _generateOTP();
      final expiresAt = DateTime.now().add(const Duration(minutes: 5));

      await _supabase.from('email_otp').upsert({
        'email': email,
        'otp': otp,
        'expires_at': expiresAt.toIso8601String(),
      });

      print('📧 OTP sent to email: $email, Code: $otp');

      return otp;
    } catch (e) {
      throw Exception('Failed to send OTP to Email: $e');
    }
  }

  /// **التحقق من صلاحية الرمز**
  Future<bool> validateOTP(String identifier, String otp) async {
    try {
      final isEmail = identifier.contains('@');
      final table = isEmail ? 'email_otp' : 'otp';
      final column = isEmail ? 'email' : 'phone';

      final data = await _supabase
          .from(table)
          .select()
          .eq(column, identifier)
          .maybeSingle();

      if (data == null) return false;

      final storedOtp = data['otp'] as String?;
      final expiresAt = DateTime.tryParse(data['expires_at'] ?? '');

      if (storedOtp == null || expiresAt == null) return false;

      final isValid = storedOtp == otp && DateTime.now().isBefore(expiresAt);

      print("✅ Stored OTP: $storedOtp, Entered OTP: $otp, Valid: $isValid");

      return isValid;
    } catch (e) {
      throw Exception('Failed to validate OTP: $e');
    }
  }

  /// **توليد رمز OTP عشوائي مكون من 6 أرقام**
  String _generateOTP() {
    final random = Random();
    return (random.nextInt(900000) + 100000).toString(); // 6 digits
  }
}
