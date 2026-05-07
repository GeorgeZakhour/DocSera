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
/// The base shape comes from rpc_get_my_pending_link_requests (id, kind,
/// doctor_id, doctor_name, ...). The service hydrates additional doctor
/// presentation fields (image, title, specialty, clinic) from
/// public_doctors so the review page can render a proper hero card.
class PatientLinkRequest {
  final String id;
  final String kind; // 'connect' | 'merge' | 'relative_promotion'
  final String doctorId;
  final String doctorName;
  final String? doctorImage;
  final String? doctorTitle;     // 'د.', 'أ.د.', etc.
  final String? doctorGender;    // used to pick the gendered fallback avatar
  final String? doctorSpecialty;
  final String? doctorClinic;
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
    required this.doctorImage,
    required this.doctorTitle,
    required this.doctorGender,
    required this.doctorSpecialty,
    required this.doctorClinic,
    required this.targetUserId,
    required this.targetRelativeId,
    required this.manualPatientId,
    required this.createdAt,
    required this.expiresAt,
  });

  factory PatientLinkRequest.fromMap(
    Map<String, dynamic> map, {
    Map<String, dynamic>? doctorRow,
  }) {
    return PatientLinkRequest(
      id: map['id'] as String,
      kind: map['kind'] as String,
      doctorId: map['doctor_id'] as String,
      doctorName: (map['doctor_name'] as String?)?.trim()
          ?? _composeName(doctorRow),
      doctorImage: doctorRow?['doctor_image'] as String?,
      doctorTitle: doctorRow?['title'] as String?,
      doctorGender: doctorRow?['gender'] as String?,
      doctorSpecialty: doctorRow?['specialty'] as String?,
      doctorClinic: doctorRow?['clinic'] as String?,
      targetUserId: map['target_user_id'] as String?,
      targetRelativeId: map['target_relative_id'] as String?,
      manualPatientId: map['manual_patient_id'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      expiresAt: DateTime.parse(map['expires_at'] as String),
    );
  }

  static String _composeName(Map<String, dynamic>? d) {
    if (d == null) return '';
    final t = (d['title'] as String?)?.trim() ?? '';
    final f = (d['first_name'] as String?)?.trim() ?? '';
    final l = (d['last_name'] as String?)?.trim() ?? '';
    return [t, f, l].where((s) => s.isNotEmpty).join(' ');
  }

  bool get isForRelative => targetRelativeId != null;
  bool get isMerge => kind == 'merge';
  bool get isConnect => kind == 'connect';

  /// Display name without title (e.g. "أحمد خليل" instead of "د. أحمد خليل")
  /// — used when the title is rendered separately as a chip.
  String get nameWithoutTitle {
    if (doctorTitle == null || doctorTitle!.isEmpty) return doctorName;
    final t = doctorTitle!.trim();
    if (doctorName.startsWith('$t ')) {
      return doctorName.substring(t.length + 1).trim();
    }
    return doctorName;
  }
}

class PatientLinkRequestsService {
  PatientLinkRequestsService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// All pending link requests targeting the current user or any of their
  /// relatives. Sorted by recency (RPC handles ordering). Doctor
  /// presentation fields are hydrated from public_doctors so each row
  /// carries its image/specialty/clinic for the review page hero.
  Future<List<PatientLinkRequest>> fetchPending() async {
    final response = await _client.rpc('rpc_get_my_pending_link_requests');
    if (response is! List || response.isEmpty) return const [];

    final base = response.cast<Map<String, dynamic>>();
    final doctorIds = base.map((r) => r['doctor_id'] as String).toSet().toList();

    final doctorRows = await _client
        .from('public_doctors')
        .select('id, first_name, last_name, title, gender, specialty, clinic, doctor_image')
        .inFilter('id', doctorIds);

    final byId = <String, Map<String, dynamic>>{
      for (final r in (doctorRows as List).cast<Map<String, dynamic>>())
        r['id'] as String: r,
    };

    return base
        .map((row) => PatientLinkRequest.fromMap(
              row,
              doctorRow: byId[row['doctor_id'] as String],
            ))
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
