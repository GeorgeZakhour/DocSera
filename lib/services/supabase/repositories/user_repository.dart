import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../utils/time_utils.dart';

class UserRepository {
  final SupabaseClient _supabase;

  UserRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  /// ✅ إضافة مستخدم جديد إلى جدول Supabase (آمن ضد null)
  Future<void> addUser(Map<String, dynamic> userData) async {
    try {
      // 🕐 timestamps
      userData['created_at'] = DocSeraTime.nowUtc().toIso8601String();
      userData['updated_at'] = DocSeraTime.nowUtc().toIso8601String();

      // 🧹 تنظيف null
      final safeData = <String, dynamic>{};
      userData.forEach((key, value) {
        if (value == null) {
          safeData[key] =
          (key.contains('verified') ||
              key.contains('accepted') ||
              key.contains('checked') ||
              key.contains('enabled'))
              ? false
              : "";
        } else {
          safeData[key] = value;
        }
      });

      debugPrint("📤 inserting user:");
      safeData.forEach((k, v) => debugPrint("  $k => $v"));

      await _supabase
          .from('users')
          .insert(safeData);

    } catch (e, s) {
      debugPrint("❌ addUser failed: $e");
      debugPrint(s.toString());
      rethrow;
    }
  }

  /// ✅ جلب بيانات مستخدم حسب ID (via RPC)
  Future<Map<String, dynamic>?> getUserData(String userId) async {
    try {
      // ✅ rpc_get_my_user يعتمد على auth.uid() داخل قاعدة البيانات
      final dynamic res = await _supabase.rpc('rpc_get_my_user');

      // Supabase rpc قد يرجع null أو Map أو JSON (dynamic)
      if (res == null) return null;

      if (res is Map<String, dynamic>) {
        return res;
      }
      // في حال رجعت String JSON (حسب إعدادات/نسخ)
      if (res is String) {
        return (jsonDecode(res) as Map).cast<String, dynamic>();
      }

      // أي شكل غير متوقع
      throw Exception('rpc_get_my_user returned unsupported type: ${res.runtimeType}');
    } catch (e) {
      throw Exception('Failed to fetch user data via RPC: $e');
    }
  }

  /// ✅ تحديث بيانات مستخدم
  Future<void> updateUser(String userId, Map<String, dynamic> updatedData) async {
    try {
      updatedData['updated_at'] = DocSeraTime.nowUtc().toIso8601String();

      final response = await _supabase
          .from('users')
          .update(updatedData)
          .eq('id', userId);

      if (response.error != null) {
        throw Exception('Update failed: ${response.error!.message}');
      }
    } catch (e) {
      throw Exception('Failed to update user: ${e.toString()}');
    }
  }

  /// ✅ جلب مستخدمين مجزئين (Paginated)
  Future<List<Map<String, dynamic>>> getPaginatedUsers({String? lastCreatedAt, int limit = 10}) async {
    try {
      if (lastCreatedAt != null) {
        final result = await _supabase
            .from('users')
            .select()
            .gt('created_at', lastCreatedAt)
            .order('created_at')
            .limit(limit);
        return List<Map<String, dynamic>>.from(result);
      } else {
        final result = await _supabase
            .from('users')
            .select()
            .order('created_at')
            .limit(limit);
        return List<Map<String, dynamic>>.from(result);
      }
    } catch (e) {
      throw Exception('Error retrieving paginated users: $e');
    }
  }
}
