import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

class AccountProfileService {
  final SupabaseClient _supabase;

  AccountProfileService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  /// ✅ getMyUser() → rpc_get_my_user
  /// يعتمد على auth.uid() داخل الـ DB (لا تمرر userId)
  Future<Map<String, dynamic>?> getMyUser() async {
    try {
      final dynamic res = await _supabase.rpc('rpc_get_my_user');

      if (res == null) return null;

      if (res is Map<String, dynamic>) return res;

      if (res is String) {
        return (jsonDecode(res) as Map).cast<String, dynamic>();
      }

      throw Exception(
        'rpc_get_my_user returned unsupported type: ${res.runtimeType}',
      );
    } catch (e) {
      throw Exception('AccountProfileService.getMyUser failed: $e');
    }
  }

  /// ✅ updateMyUser(payload) → rpc_update_my_user
  /// payload: الحقول المسموح تعديلها فقط (مثلاً first_name/last_name/gender/dob..)
  Future<void> updateMyUser(Map<String, dynamic> payload) async {
    try {
      // يفضّل أن rpc_update_my_user نفسه يحدّد whitelist للحقول المسموحة
      await _supabase.rpc('rpc_update_my_user', params: {'payload': payload});
    } catch (e) {
      throw Exception('AccountProfileService.updateMyUser failed: $e');
    }
  }
}
