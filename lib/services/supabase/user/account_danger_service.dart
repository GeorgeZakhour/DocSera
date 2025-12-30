import 'package:supabase_flutter/supabase_flutter.dart';

class AccountDangerService {
  final SupabaseClient _supabase;

  AccountDangerService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  Future<void> deleteMyAccount() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('NOT_AUTHENTICATED');

      await _supabase.rpc('rpc_deactivate_my_account');

      // 🔐 sign out locally
      await _supabase.auth.signOut();
    } catch (e) {
      throw Exception('deleteMyAccount failed: $e');
    }
  }
}
