import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:docsera/utils/shared_prefs_service.dart';
import '../../storage/secure_storage_service.dart';
import 'package:docsera/services/notifications/notification_service.dart';

class AuthRepository {
  final SupabaseClient _supabase;
  final SharedPrefsService _sharedPrefsService = SharedPrefsService();

  AuthRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  /// ✅ التحقق مما إذا كان رقم الهاتف موجود مسبقًا في Supabase
  Future<bool> isPhoneNumberExists(String phoneNumber) async {
    debugPrint("📞 Checking if phone number exists: $phoneNumber");

    final response = await _supabase.rpc(
      'rpc_check_phone_exists',
      params: {'p_phone': phoneNumber},
    );

    final exists = response == true;
    debugPrint("📊 Matching phone: ${exists ? "FOUND" : "NOT FOUND"}");

    return exists;
  }

  // ==========================================
  // 📱 PHONE OTP EDGE FUNCTION CALLS
  // ==========================================

  /// 📩 إرسال رمز OTP للرقم (Syriatel)
  Future<void> sendPhoneOtp(String phone, {bool isLogin = false}) async {
    await _supabase.functions.invoke(
      'send_sms_otp',
      body: {
        'phone': phone,
        'purpose': isLogin ? 'login' : 'signup_phone_verify',
      },
    );
  }

  /// 🔐 التحقق من رمز OTP المدخل
  Future<bool> verifyPhoneOtp(String phone, String code) async {
    try {
      final res = await _supabase.rpc(
        'rpc_verify_phone_otp',
        params: {
          'p_phone': phone,
          'p_code': code,
        },
      );
      return res == true;
    } catch (_) {
      return false;
    }
  }

  /// 📧 إرسال رمز OTP للبريد الإلكتروني للتحقق أثناء التسجيل
  Future<void> sendEmailOtp(String email) async {
    final res = await _supabase.functions.invoke(
      'send_doctor_otp', // مشتركة بين التطبيقين
      body: {
        'email': email,
        'purpose': 'signup_email_verify',
      },
    );

    if (res.status != 200) {
      throw Exception('Failed to send verification email');
    }
  }

  /// ✅ التحقق من رمز OTP للبريد الإلكتروني (بدون استهلاكه)
  Future<bool> verifyEmailOtp(String email, String code) async {
    try {
      final res = await _supabase.rpc(
        'rpc_validate_doctor_otp_peek', // مشتركة
        params: {
          'p_email': email,
          'p_code': code,
          'p_purpose': 'signup_email_verify',
        },
      );
      return res == true;
    } catch (_) {
      return false;
    }
  }

  /// 🚪 تسجيل الدخول برقم الهاتف ورمز OTP السرياليتل
  Future<AuthResponse> phoneOtpLogin(String phone, String code) async {
    final response = await _supabase.functions.invoke(
      'phone_otp_login',
      body: {
        'phone': phone,
        'code': code,
        'app': 'docsera',
      },
    );
    final data = response.data;
    if (data['error'] != null) {
      throw Exception(data['error']);
    }
    return await _supabase.auth.setSession(
      data['refresh_token'],
    );
  }

  /// 🆕 إنشاء حساب للمريض برقم الهاتف عن طريق Edge Function
  Future<AuthResponse> phoneOtpSignup({
    required String phone,
    required String code,
  }) async {
    final response = await _supabase.functions.invoke(
      'phone_otp_signup',
      body: {
        'phone': phone,
        'otp_code': code,
        'app': 'docsera',
      },
    );
    final data = response.data;
    if (data['error'] != null) {
      throw Exception(data['error']);
    }
    return await _supabase.auth.setSession(
      data['refresh_token'],
    );
  }

  // ==========================================

  /// ✅ تسجيل الدخول باستخدام البريد وكلمة المرور
  Future<AuthResponse> signInWithPassword({required String email, required String password}) async {
    return await _supabase.auth.signInWithPassword(email: email, password: password);
  }

  /// ✅ تسجيل الخروج
  Future<void> signOut() async {
    try {
      await NotificationService.instance.deleteToken(); // ✅ Remove device token
      await _supabase.auth.signOut();
    } catch (e) {
      debugPrint("❌ Sign out error: $e");
    }
  }

  /// ✅ الحصول على المستخدم الحالي
  User? getCurrentUser() {
    return _supabase.auth.currentUser;
  }

  /// ✅ البحث عن مستخدم عبر البريد أو الهاتف
  /// ✅ Pre-login lookup (works with strict RLS) via RPC
  /// Returns only: email, is_active, user_id
  Future<Map<String, dynamic>> getLoginInfoByEmailOrPhone(String input) async {
    try {
      final identifier = input.trim();

      final dynamic res = await _supabase.rpc(
        'rpc_get_login_info',
        params: {'p_identifier': identifier},
      );

      if (res == null) {
        throw Exception('User not found');
      }

      // Supabase can return either Map or List depending on version/settings
      if (res is List) {
        if (res.isEmpty) throw Exception('User not found');
        return Map<String, dynamic>.from(res.first as Map);
      }

      if (res is Map) {
        return Map<String, dynamic>.from(res);
      }

      throw Exception('rpc_get_login_info returned unsupported type: ${res.runtimeType}');
    } catch (e) {
      throw Exception('Error retrieving login info via RPC: $e');
    }
  }

  Future<Map<String, dynamic>> getMySecurityState() async {
    final res = await _supabase.rpc('rpc_get_my_security_state');

    if (res == null) {
      throw Exception('Security state not found');
    }

    if (res is Map<String, dynamic>) return res;
    if (res is String) return jsonDecode(res) as Map<String, dynamic>;

    throw Exception('Invalid security state response');
  }

  /// ✅ التحقق من وجود مستخدم بالبريد أو الهاتف
  Future<bool> doesUserExist({String? email, String? phoneNumber}) async {
    try {
      if (email != null) {
        final emailMatch = await _supabase.rpc(
          'check_email_context',
          params: {'p_email': email.toLowerCase()},
        );
        if (emailMatch != 'none') return true;
      }

      if (phoneNumber != null) {
        final phoneMatch = await _supabase.rpc(
          'rpc_check_phone_exists',
          params: {'p_phone': phoneNumber},
        );
        if (phoneMatch == true) return true;
      }

      return false;
    } catch (e) {
      throw Exception('Error checking for duplicates: $e');
    }
  }

  /// 📡 التحقق من حالة البريد الإلكتروني (غير موجود، في التطبيق الأول، الثاني، أو كلاهما)
  Future<String> checkEmailContext(String email) async {
    final res = await _supabase.rpc(
      'check_email_context',
      params: {'p_email': email.toLowerCase()},
    );
    return res as String;
  }

  /// ✅ حذف حساب المستخدم (Soft Delete via RPC)
  Future<void> deleteUserAccount() async {
    try {
      debugPrint("🔍 Starting secure account deletion...");

      // 1. Call Secure RPC to Soft Delete on Backend
      await _supabase.rpc('rpc_soft_delete_account');
      debugPrint("✅ RPC soft delete called successfully.");

      // 2. Sign Out Locally
      await _supabase.auth.signOut();
      debugPrint("✅ Signed out.");

      // 3. Clear Local Storage
      // Secure Storage
      await const SecureStorageService().removePersistedSession();

      // Shared Preferences
      await _sharedPrefsService.saveData('isLoggedIn', false);
      await _sharedPrefsService.removeData('userId');
      await _sharedPrefsService.removeData('userEmail');
      await _sharedPrefsService.removeData('userName');
      await _sharedPrefsService.removeData('favoriteDoctors');
      await _sharedPrefsService.removeData('upcomingAppointments');
      await _sharedPrefsService.removeData('pastAppointments');

      final prefs = await SharedPreferences.getInstance();
      await prefs.clear(); // Wipe everything else just in case
      debugPrint("🧼 Local storage cleared.");

      // 4. Clear Biometric Credentials
      // Ideally handled by BiometricStorage service, but prefs.clear() handles the flags.

      debugPrint("✅ Secure account deletion complete.");

    } catch (e) {
      debugPrint("❌ Error deleting user account: $e");
      throw Exception("Failed to delete account. Please try again or contact support.");
    }
  }
}
