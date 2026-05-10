
import 'package:docsera/services/biometrics/biometric_storage.dart';
import 'package:docsera/services/notifications/notification_service.dart';
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

  /// requestPhoneChange(e164) → send_sms_otp edge function
  ///
  /// Migrated from the legacy rpc_request_phone_change which leaked the
  /// OTP back to the client. Now uses the same unified edge function
  /// that DocSera-Pro signup + login + cross-app flows use:
  ///   * Real Syriatel SMS for production phones
  ///   * Test-phone whitelist (00963900000001..13) accepting "123456"
  ///   * OTP stored as a sha256 hash in doctor_phone_otps — never
  ///     returned to the client
  Future<void> requestPhoneChange(String e164) async {
    try {
      final res = await _supabase.functions.invoke(
        'send_sms_otp',
        body: {
          'phone': e164,
          'purpose': 'phone_change',
        },
      );
      final data = res.data;
      if (data is Map && data['error'] != null) {
        throw Exception(data['error'].toString());
      }
    } catch (e) {
      throw Exception('AccountSecurityService.requestPhoneChange failed: $e');
    }
  }


  /// verifyPhoneOtp(e164, otp) → rpc_verify_phone_otp(3-arg, unified)
  ///
  /// The unified RPC consults doctor_phone_otps (sha256-hashed). On
  /// success we still need to write the new phone onto public.users —
  /// the legacy 2-arg RPC did that inline; the 3-arg unified RPC just
  /// validates the code, so we update separately via rpc_update_my_user.
  Future<void> verifyPhoneOtp(String e164, String otp) async {
    try {
      final ok = await _supabase.rpc(
        'rpc_verify_phone_otp',
        params: {
          'p_phone': e164,
          'p_code': otp,
          'p_purpose': 'phone_change',
        },
      );
      if (ok != true) {
        throw Exception('INVALID_OTP');
      }
      // Persist the new phone on public.users now that it's verified.
      await _supabase.rpc(
        'rpc_set_my_phone',
        params: {
          'p_phone': e164,
          'p_verified': true,
        },
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
        // Read existing credentials from the secure store (which already
        // handles legacy SharedPreferences migration) and re-save with the
        // new email. Plaintext password is NEVER read from prefs anymore.
        final existing = await BiometricStorage.getCredentials();
        if (existing != null && existing['password'] != null) {
          await BiometricStorage.saveCredentials(
            email: email,
            password: existing['password']!,
          );
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
    bool signOutOtherDevices = false,
    String? currentDeviceId,
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

      // 3) Optional: invalidate every OTHER session for this user. The
      //    RPC runs FIRST so it executes while our auth session is
      //    guaranteed valid; signOut(scope: others) is then best-effort.
      //    Two parts because they cover separate state:
      //      a. rpc_clear_trusted_devices_except_current strips
      //         trusted_devices down to the current device and DELETEs
      //         every other user_devices row. The realtime listener on
      //         those rows fires on each affected device, signing them
      //         out instantly (within ~1s).
      //      b. signOut(scope: others) revokes refresh tokens server-
      //         side as a backstop in case realtime didn't reach the
      //         device (offline, app killed, etc.) — they'll get
      //         kicked next time their access token expires (~1h).
      if (signOutOtherDevices) {
        if (currentDeviceId != null && currentDeviceId.isNotEmpty) {
          try {
            await _supabase.rpc(
              'rpc_clear_trusted_devices_except_current',
              params: {
                'p_device_id': currentDeviceId,
                // Pass our Pushy token so the RPC keeps OUR user_devices
                // row and deletes every other one. If null (e.g. iOS
                // hasn't completed Pushy registration), the RPC skips
                // user_devices DELETE but still updates trusted_devices.
                'p_pushy_token': NotificationService.instance.pushyDeviceToken,
              },
            );
          } catch (_) { /* best effort */ }
        }
        try {
          await _supabase.auth.signOut(scope: SignOutScope.others);
        } catch (_) { /* best effort */ }
      }
    } catch (e) {
      throw Exception('AccountSecurityService.changePassword failed: $e');
    }
  }
}
