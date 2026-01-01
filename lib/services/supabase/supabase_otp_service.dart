import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseOTPService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ---------------------------------------------------------------------------
  // 📱 SMS OTP — يبقى كما هو (محلي + Snackbar)
  // ---------------------------------------------------------------------------
  Future<String> sendOTPToPhone(String phoneNumber) async {
    try {
      final otp = _generateOTP();
      final expiresAt = DateTime.now().add(const Duration(minutes: 5));

      await _supabase.from('otp').upsert({
        'phone': phoneNumber,
        'otp': otp,
        'expires_at': expiresAt.toIso8601String(),
      });

      debugPrint('📱 OTP sent to phone: $phoneNumber, Code: $otp');
      return otp;
    } catch (e) {
      throw Exception('Failed to send OTP to phone: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // 📧 Email OTP — Edge Function (بدون OTP محلي)
  // ---------------------------------------------------------------------------
  Future<void> sendEmailOtp(String email) async {
    final res = await _supabase.functions.invoke(
      'send_email_otp',
      body: {
        'email': email,
      },
    );

    if (res.status != 200) {
      throw Exception('Failed to send email OTP');
    }
  }

  // ---------------------------------------------------------------------------
  // 📧 Verify Email OTP — RPC
  // ---------------------------------------------------------------------------
  Future<bool> verifyEmailOtp(String email, String code) async {
    final res = await _supabase.rpc(
      'rpc_verify_email_otp',
      params: {
        'p_email': email,
        'p_code': code,
        'p_purpose': 'signup_email_verify',
      },
    );

    return res == true;
  }

  // ---------------------------------------------------------------------------
  // 🔢 OTP Generator (SMS فقط)
  // ---------------------------------------------------------------------------
  String _generateOTP() {
    final random = Random();
    return (random.nextInt(900000) + 100000).toString();
  }
}
