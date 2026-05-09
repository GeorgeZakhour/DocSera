import 'package:supabase_flutter/supabase_flutter.dart';

class AccountDangerService {
  final SupabaseClient _supabase;

  AccountDangerService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  /// Account deletion (Tier 2): permanent deletion request with a 30-day
  /// cancellation window. After 30 days the account is pseudonymized
  /// (medical records kept anonymized for the doctor's clinical files);
  /// after 7 years hard-purged. This is what the "Delete account" sheet
  /// calls — the prior wiring incorrectly hit the Tier 1 deactivate RPC,
  /// trapping users without a deletion timestamp and skipping the entire
  /// 30-day notification lifecycle (no T-7d / T-1d warnings, no
  /// PendingDeletionPage routing).
  Future<Map<String, dynamic>> deleteMyAccount() async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('NOT_AUTHENTICATED');

    final res = await _supabase.rpc('rpc_request_account_deletion');

    // Sign out locally so the user lands on the login screen and the next
    // sign-in can route them to the cancel-deletion page (login flow now
    // distinguishes a soft pending-deletion state from a hard ban).
    await _supabase.auth.signOut();

    return Map<String, dynamic>.from(res as Map);
  }

  /// Same as deleteMyAccount — kept for any future caller that wants the
  /// explicit name. Tier 2 deletion (30-day grace window).
  Future<Map<String, dynamic>> requestPermanentDeletion() async {
    final res = await _supabase.rpc('rpc_request_account_deletion');
    return Map<String, dynamic>.from(res as Map);
  }

  /// Tier 1: legacy soft-deactivate (recoverable on next login). Kept for
  /// flows that explicitly want this — currently none in the patient app.
  Future<void> deactivateMyAccount() async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('NOT_AUTHENTICATED');
    await _supabase.rpc('rpc_deactivate_my_account');
    await _supabase.auth.signOut();
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
