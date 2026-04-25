import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CompleteHealthProfileResult {
  final bool alreadyAwarded;
  final int newBalance;
  final DateTime completedAt;

  CompleteHealthProfileResult({
    required this.alreadyAwarded,
    required this.newBalance,
    required this.completedAt,
  });

  factory CompleteHealthProfileResult.fromMap(Map<String, dynamic> m) =>
      CompleteHealthProfileResult(
        alreadyAwarded: m['already_awarded'] as bool? ?? false,
        newBalance: (m['new_balance'] as num?)?.toInt() ?? 0,
        completedAt: DateTime.parse(
            m['completed_at'] as String? ?? DateTime.now().toIso8601String()),
      );
}

class HealthProfileRepository {
  final SupabaseClient _client;

  HealthProfileRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// Builds the params map for [upsertVitalsLifestyle], excluding null values
  /// so that the RPC's `DEFAULT NULL` parameters are not overwritten.
  ///
  /// Exposed as a `static` method so it can be unit-tested without a
  /// live Supabase client.
  @visibleForTesting
  static Map<String, dynamic> buildUpsertParams({
    num? heightCm,
    num? weightKg,
    String? sportFrequency,
    String? smokingStatus,
    String? alcoholFrequency,
  }) {
    final params = <String, dynamic>{};
    if (heightCm != null) params['p_height_cm'] = heightCm;
    if (weightKg != null) params['p_weight_kg'] = weightKg;
    if (sportFrequency != null) params['p_sport_frequency'] = sportFrequency;
    if (smokingStatus != null) params['p_smoking_status'] = smokingStatus;
    if (alcoholFrequency != null) params['p_alcohol_frequency'] = alcoholFrequency;
    return params;
  }

  /// Calls the `complete_health_profile` RPC and returns the structured result.
  Future<CompleteHealthProfileResult> completeHealthProfile() async {
    final res = await _client.rpc('complete_health_profile');
    return CompleteHealthProfileResult.fromMap(
        Map<String, dynamic>.from(res as Map));
  }

  /// Calls the `upsert_health_profile_vitals_lifestyle` RPC.
  /// Only non-null arguments are included so the DB function's
  /// `DEFAULT NULL` handling is preserved for unspecified fields.
  Future<void> upsertVitalsLifestyle({
    num? heightCm,
    num? weightKg,
    String? sportFrequency,
    String? smokingStatus,
    String? alcoholFrequency,
  }) async {
    final params = buildUpsertParams(
      heightCm: heightCm,
      weightKg: weightKg,
      sportFrequency: sportFrequency,
      smokingStatus: smokingStatus,
      alcoholFrequency: alcoholFrequency,
    );

    await _client.rpc(
      'upsert_health_profile_vitals_lifestyle',
      params: params,
    );
  }

  /// Reads the current `patient_health_profile` row for [userId], or null if
  /// no row exists yet. Used by the wizard to hydrate prior answers.
  Future<Map<String, dynamic>?> fetchOwnProfile(String userId) async {
    final res = await _client
        .from('patient_health_profile')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    return res;
  }
}
