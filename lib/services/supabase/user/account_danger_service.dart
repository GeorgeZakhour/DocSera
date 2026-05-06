import 'package:supabase_flutter/supabase_flutter.dart';

class AccountDangerService {
  final SupabaseClient _supabase;

  AccountDangerService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  /// Tier 1 — recoverable deactivation. The user can sign back in any time
  /// and the account reactivates. No 30-day window.
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

  /// Tier 2 — permanent deletion request. Sets a 30-day cancellation
  /// window. After 30 days the account is pseudonymized (medical records
  /// kept anonymized for the doctor's clinical files); after 7 years
  /// hard-purged.
  Future<Map<String, dynamic>> requestPermanentDeletion() async {
    final res = await _supabase.rpc('rpc_request_account_deletion');
    return Map<String, dynamic>.from(res as Map);
  }

  /// Cancel a pending Tier 2 deletion within the 30-day window. The
  /// account is reactivated.
  Future<Map<String, dynamic>> cancelPermanentDeletion() async {
    final res = await _supabase.rpc('rpc_cancel_account_deletion');
    return Map<String, dynamic>.from(res as Map);
  }

  /// Read-only status query — used by the login guard and the
  /// PendingDeletionPage to render the right state.
  Future<Map<String, dynamic>?> getDeletionStatus() async {
    try {
      final res = await _supabase.rpc('rpc_get_account_deletion_status');
      if (res == null) return null;
      return Map<String, dynamic>.from(res as Map);
    } catch (_) {
      return null;
    }
  }
}
