// Data layer for incoming patient↔doctor link requests on the patient side.
//
// Two RPCs back this:
//   rpc_get_my_pending_link_requests — list of pending requests for the
//     current user (and any relatives they manage). RLS-scoped server-side.
//   rpc_respond_patient_link — approve or reject a pending request. The
//     server resolves the kind ('connect'/'merge'/'relative_promotion') and
//     applies the correct effect.

import 'package:supabase_flutter/supabase_flutter.dart';

/// One pending link request shown in the patient inbox / review page.
///
/// Mirrors the row shape returned by rpc_get_my_pending_link_requests.
class PatientLinkRequest {
  final String id;
  final String kind; // 'connect' | 'merge' | 'relative_promotion'
  final String doctorId;
  final String doctorName;
  final String? targetUserId;
  final String? targetRelativeId;
  final String? manualPatientId;
  final DateTime createdAt;
  final DateTime expiresAt;

  const PatientLinkRequest({
    required this.id,
    required this.kind,
    required this.doctorId,
    required this.doctorName,
    required this.targetUserId,
    required this.targetRelativeId,
    required this.manualPatientId,
    required this.createdAt,
    required this.expiresAt,
  });

  factory PatientLinkRequest.fromMap(Map<String, dynamic> map) {
    return PatientLinkRequest(
      id: map['id'] as String,
      kind: map['kind'] as String,
      doctorId: map['doctor_id'] as String,
      doctorName: (map['doctor_name'] as String?)?.trim() ?? '',
      targetUserId: map['target_user_id'] as String?,
      targetRelativeId: map['target_relative_id'] as String?,
      manualPatientId: map['manual_patient_id'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      expiresAt: DateTime.parse(map['expires_at'] as String),
    );
  }

  bool get isForRelative => targetRelativeId != null;
  bool get isMerge => kind == 'merge';
  bool get isConnect => kind == 'connect';
}

class PatientLinkRequestsService {
  PatientLinkRequestsService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// All pending link requests targeting the current user or any of their
  /// relatives. Sorted by recency (RPC handles ordering).
  Future<List<PatientLinkRequest>> fetchPending() async {
    final response = await _client.rpc('rpc_get_my_pending_link_requests');
    if (response is! List) return const [];
    return response
        .map((e) => PatientLinkRequest.fromMap(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Fetch a single pending request by id (RLS gates access to the
  /// caller's own rows). Returns null if not found / not theirs / not
  /// pending — the review page will treat any of those as "request no
  /// longer available".
  Future<PatientLinkRequest?> fetchById(String requestId) async {
    final all = await fetchPending();
    for (final req in all) {
      if (req.id == requestId) return req;
    }
    return null;
  }

  /// Approve or reject the request. Server-side this calls into the
  /// appropriate apply helper (_link_apply_connect / _link_apply_merge)
  /// when approved, or just flips status to 'rejected' otherwise.
  ///
  /// Returns the resolved status string from the server: 'connected',
  /// 'merged', or 'rejected'.
  Future<String> respond({
    required String requestId,
    required bool approve,
  }) async {
    final response = await _client.rpc(
      'rpc_respond_patient_link',
      params: {
        'p_request_id': requestId,
        'p_approve': approve,
        'p_response_choice': null,
      },
    );
    return (response as String?) ?? 'unknown';
  }
}
