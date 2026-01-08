
import 'package:docsera/services/biometrics/biometric_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AccountSecurityService {
  final SupabaseClient _supabase;

  AccountSecurityService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  // ---------------------------------------------------------------------------
  // Availability checks (RPC مخصص)
  // ---------------------------------------------------------------------------

  /// ✅ isPhoneAvailable(e164) → RPC مخصص
  /// يرجع true إذا الهاتف غير مستخدم من أي حساب آخر
  Future<bool> isPhoneAvailable(String e164) async {
    try {
      final dynamic res = await _supabase.rpc(
        'rpc_is_phone_available',
        params: {'e164': e164},
      );

      if (res is bool) return res;

      // أحيانًا يرجع 0/1 أو "t/f" حسب تنفيذ SQL
      if (res is num) return res == 1;
      if (res is String) return res.toLowerCase() == 'true' || res == 't';

      throw Exception('rpc_is_phone_available returned: ${res.runtimeType}');
    } catch (e) {
      throw Exception('AccountSecurityService.isPhoneAvailable failed: $e');
    }
  }

  /// ✅ isEmailAvailable(email) → RPC مخصص
  Future<bool> isEmailAvailable(String email) async {
    try {
      final dynamic res = await _supabase.rpc(
        'rpc_is_email_available',
        params: {'p_email': email},
      );

      if (res is bool) return res;
      if (res is num) return res == 1;
      if (res is String) return res.toLowerCase() == 'true' || res == 't';

      throw Exception('rpc_is_email_available returned: ${res.runtimeType}');
    } catch (e) {
      throw Exception('AccountSecurityService.isEmailAvailable failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Phone change flow (OTP)
  // ---------------------------------------------------------------------------

  /// ✅ requestPhoneChange(e164) → rpc_request_phone_change
  /// يتوقع أن الـ RPC يقوم بإنشاء OTP وإرساله (SMS/WhatsApp/Provider)
  Future<String> requestPhoneChange(String e164) async {
    try {
      final res = await _supabase.rpc(
        'rpc_request_phone_change',
        params: {'e164': e164},
      );

      if (res == null) {
        throw Exception('OTP not returned');
      }

      return res.toString();
    } catch (e) {
      throw Exception('AccountSecurityService.requestPhoneChange failed: $e');
    }
  }


  /// ✅ verifyPhoneOtp(e164, otp) → rpc_verify_phone_otp
  /// يتوقع أن الـ RPC يتحقق ثم يحدّث الهاتف (أو يثبت طلب التغيير)
  Future<void> verifyPhoneOtp(String e164, String otp) async {
    try {
      await _supabase.rpc(
        'rpc_verify_phone_otp',
        params: {'e164': e164, 'p_otp': otp},
      );
    } catch (e) {
      throw Exception('AccountSecurityService.verifyPhoneOtp failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Email change flow (OTP)
  // ---------------------------------------------------------------------------

  /// ✅ requestEmailChange(email) → send_email_otp (Edge Function)
  /// Uses the same function used in signup to ensure consistency (Mailgun + Rate Limits)
  Future<void> requestEmailChange(String email) async {
    try {
      final res = await _supabase.functions.invoke(
        'send_email_otp',
        body: {'email': email},
      );

      if (res.status != 200) {
        throw Exception('Failed to send email OTP');
      }
    } catch (e) {
      throw Exception('AccountSecurityService.requestEmailChange failed: $e');
    }
  }



  /// ✅ verifyEmailOtp(email, otp) → rpc_verify_email_otp
  /// Verifies the OTP using the same logic as signup (p_purpose = 'signup_email_verify')
  Future<void> verifyEmailOtp(String email, String otp) async {
    try {
      await _supabase.rpc(
        'rpc_verify_email_otp',
        params: {
          'p_email': email,
          'p_code': otp,
          'p_purpose': 'signup_email_verify',
        },
      );
    } catch (e) {
      throw Exception('AccountSecurityService.verifyEmailOtp failed: $e');
    }
  }

  /// ✅ updateEmail(email)
  /// Actually updates the user's email in Auth after successful verification
  Future<void> updateEmail(String email) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      final res = await _supabase.functions.invoke(
        'update_email_admin',
        body: {'email': email},
      );

      if (res.status != 200) {
        throw Exception('Failed to update email via Admin Function');
      }

      // ✅ Update Biometric Storage if enabled
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('enableFaceID') == true) {
        // We need the password to re-save credentials.
        // Option 1: Ask user for password (too much friction)
        // Option 2: Read old password from storage (if exists) and re-save with new email
        final oldPassword = prefs.getString('userPassword');
        if (oldPassword != null) {
          await BiometricStorage.saveCredentials(email: email, password: oldPassword);
        }
      }
    } catch (e) {
      throw Exception('AccountSecurityService.updateEmail failed: $e');
    }
  }


  // ---------------------------------------------------------------------------
  // Security settings (future)
  // ---------------------------------------------------------------------------

  /// ✅ updateMySecurity(payload) → rpc_update_my_security
  /// مثال: 2FA enabled, recovery options, etc.
  Future<void> updateMySecurity(Map<String, dynamic> payload) async {
    try {
      await _supabase.rpc(
        'rpc_update_my_security',
        params: {'payload': payload},
      );
    } catch (e) {
      throw Exception('AccountSecurityService.updateMySecurity failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Password change (reauth + update)
  // ---------------------------------------------------------------------------

  /// ✅ changePassword(current, next)
  /// الفكرة: Re-auth آمن ثم updateUser
  ///
  /// ملاحظة: إذا كان تسجيل الدخول الأساسي عندك عبر الهاتف OTP وليس email/password،
  /// فـ "reauth via signInWithPassword" غير صالح. وقتها نحتاج Flow بديل
  /// (مثلاً OTP إضافي قبل تغيير كلمة السر، أو reauth عبر provider).
  /// final user = _supabase.auth.currentUser;
  // if (user == null) {
  //   throw Exception('NOT_AUTHENTICATED');
  // }
  //
  // final email = user.email;
  // if (email == null || email.isEmpty) {
  //   // ⚠️ Future: when login via phone OTP only
  //   throw Exception('PASSWORD_CHANGE_REQUIRES_OTP_FLOW');
  // }

  Future<void> changePassword({
    required String current,
    required String next,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      final email = user.email;
      if (email == null || email.isEmpty) {
        throw Exception(
          'Cannot reauthenticate with password because user has no email. '
              'Use an OTP-based reauth flow instead.',
        );
      }

      // 1) Re-auth
      await _supabase.auth.signInWithPassword(email: email, password: current);

      // 2) Update password
      await _supabase.auth.updateUser(UserAttributes(password: next));
    } catch (e) {
      throw Exception('AccountSecurityService.changePassword failed: $e');
    }
  }
}
