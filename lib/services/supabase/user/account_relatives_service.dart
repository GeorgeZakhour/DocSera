import 'package:supabase_flutter/supabase_flutter.dart';

class AccountRelativesService {
  final _client = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getMyRelatives() async {
    // ⚠️ مهم: الـ RPC يجب أن تُرجع فقط is_active = true
    final res = await _client.rpc('rpc_get_my_relatives');
    return List<Map<String, dynamic>>.from(res);
  }

  Future<void> addRelative(Map<String, dynamic> data) async {
    await _client.rpc('rpc_add_my_relative', params: {
      'p_data': data,
    });
  }

  Future<Map<String, dynamic>> updateRelative(
      String relativeId,
      Map<String, dynamic> data,
      ) async {
    final res = await _client
        .rpc(
      'rpc_update_my_relative',
      params: {
        'p_relative_id': relativeId,
        'p_data': data,
      },
    )
        .single();

    return Map<String, dynamic>.from(res);
  }

  // ✅ الجديد
  Future<void> deactivateRelative(String relativeId) async {
    await _client.rpc(
      'rpc_deactivate_my_relative',
      params: {
        'p_relative_id': relativeId,
      },
    );
  }

  Future<bool> isPhoneExists(String phone) async {
    final res = await _client.rpc(
      'rpc_check_phone_exists',
      params: {'p_phone': phone},
    );
    return res as bool;
  }

  Future<bool> isEmailExists(String email) async {
    final res = await _client.rpc(
      'rpc_check_email_exists',
      params: {'p_email': email},
    );
    return res as bool;
  }
}
