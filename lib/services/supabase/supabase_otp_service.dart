import 'dart:math';
import 'package:docsera/utils/time_utils.dart';
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
      final expiresAt = DocSeraTime.nowUtc().add(const Duration(minutes: 5));

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
        'purpose': 'signup_email_verify',
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
  // 🔐 Forgot Password Flow
  // ---------------------------------------------------------------------------

  /// 1. Send OTP (Purpose: forgot_password)
  Future<void> sendForgotPasswordOtp(String email) async {
    final res = await _supabase.functions.invoke(
      'send_email_otp',
      body: {
        'email': email,
        'purpose': 'forgot_password', // ✅ New purpose
      },
    );

    if (res.status != 200) {
      throw Exception('Failed to send forgot password email');
    }
  }

  /// 2. Validate OTP (Peek without consuming)
  Future<bool> validateForgotPasswordOtp(String email, String code) async {
    final res = await _supabase.rpc(
      'rpc_validate_email_otp_peek',
      params: {
        'p_email': email,
        'p_code': code,
        'p_purpose': 'forgot_password',
      },
    );
    return res == true;
  }

  /// 3. Reset Password (Consume OTP + Update Password)
  Future<void> resetPassword(String email, String code, String newPassword) async {
    final res = await _supabase.functions.invoke(
      'reset_password_otp',
      body: {
        'email': email,
        'code': code,
        'newPassword': newPassword,
      },
    );

    if (res.status != 200) {
      // Parse error if possible
      throw Exception('Failed to reset password. Code might be expired.');
    }
  }

  // ---------------------------------------------------------------------------
  // 🔢 OTP Generator (SMS فقط)
  // ---------------------------------------------------------------------------
  String _generateOTP() {
    final random = Random();
    return (random.nextInt(900000) + 100000).toString();
  }
}
