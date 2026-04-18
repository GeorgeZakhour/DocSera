import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:docsera/models/document.dart';

class DocumentsService {
  final SupabaseClient _client;

  DocumentsService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// Fetch documents for a user OR a relative.
  ///
  /// Phase 2 per-patient semantics: every document carries the subject's id
  /// in `patient_id` (the main user's own id for their own uploads, or the
  /// relative's id for relative uploads).  We also match on `user_id` as a
  /// fallback for legacy rows that pre-date the patient_id backfill.  Both
  /// filters go through the patient RLS policy, which already scopes visibility
  /// to rows the caller owns or rows belonging to their relatives.
  ///
  /// Appointment attachments are excluded by RLS (`source != 'appointment'`
  /// for patients) so callers don't need to filter them out.
  Future<List<UserDocument>> fetchDocuments({
    String? userId,
    String? relativeId,
  }) async {
    final subjectId = relativeId ?? userId;
    if (subjectId == null) return const [];

    // When viewing a RELATIVE, match only patient_id (simple case).
    // When viewing the MAIN USER, match patient_id OR (user_id AND no
    // patient_id set) so legacy rows without patient_id still appear,
    // but doctor-added files assigned to a relative (patient_id != userId)
    // are excluded.
    final filter = relativeId != null
        ? 'patient_id.eq.$subjectId'
        : 'patient_id.eq.$subjectId,and(user_id.eq.$subjectId,patient_id.is.null)';

    final response = await _client
        .from('documents')
        .select(
            '*, source_doctor:doctors!documents_source_doctor_id_fkey(first_name, last_name, title)')
        .or(filter)
        .order('uploaded_at', ascending: false);

    final list = response as List;
    if (kDebugMode) {
      debugPrint('📁 DocumentsService.fetchDocuments(subject=$subjectId) → ${list.length} rows');
      final bySource = <String, int>{};
      for (final e in list) {
        final s = e['source']?.toString() ?? 'patient';
        bySource[s] = (bySource[s] ?? 0) + 1;
      }
      debugPrint('   breakdown by source: $bySource');
    }

    // Deduplicate on id — the OR query can surface the same row twice when both
    // predicates match the same record.
    final seen = <String>{};
    final result = <UserDocument>[];
    for (final e in list) {
      final map = Map<String, dynamic>.from(e);
      final id = map['id']?.toString();
      if (id != null && !seen.add(id)) continue;
      final doctorData = map['source_doctor'];
      if (doctorData is Map) {
        final title = doctorData['title'] ?? '';
        final first = doctorData['first_name'] ?? '';
        final last = doctorData['last_name'] ?? '';
        map['source_doctor_name'] = '$title $first $last'.trim();
      }
      map.remove('source_doctor');
      result.add(UserDocument.fromMap(map));
    }
    return result;
  }

  /// Fetch attachments embedded inside shared modular reports for this user or
  /// relative, and synthesise [UserDocument] entries (source='report').
  ///
  /// Report attachments live in the `reports.sections` JSONB and are stored in
  /// the `chat.attachments` bucket — not the `documents` bucket — so each
  /// synthetic entry carries `bucket: 'chat.attachments'`.
  Future<List<UserDocument>> fetchReportAttachments({
    String? userId,
    String? relativeId,
  }) async {
    if (userId == null && relativeId == null) return const [];

    try {
      // Use the SECURITY DEFINER RPC instead of a direct SELECT on `reports`.
      // The patient-side RLS on `reports` only matches on `user_id = auth.uid()`,
      // which misses modern reports that set only `patient_id` + `patient_source`.
      // The RPC applies the correct `shared_with_patient = true` + user/relative
      // match server-side and returns the full row list as JSONB.
      final rpcResult = await _client.rpc(
        'rpc_get_my_shared_reports',
        params: {
          'p_user_id': userId,
          if (relativeId != null) 'p_relative_id': relativeId,
        },
      );
      final rows = (rpcResult is List)
          ? rpcResult
          : (rpcResult is String
              ? <dynamic>[]
              : <dynamic>[]);
      if (kDebugMode) {
        debugPrint(
            '📁 DocumentsService.fetchReportAttachments(user=$userId, relative=$relativeId) → ${rows.length} reports (via rpc)');
      }
      if (rows.isEmpty) return const [];

      // The RPC returns denormalised doctor fields (doctor_name, doctor_title)
      // so we no longer need a follow-up `doctors` query.
      final List<UserDocument> synthetic = [];
      for (final row in rows) {
        final reportId = row['id']?.toString() ?? '';
        final doctorId = row['doctor_id']?.toString();
        final doctorTitle = row['doctor_title']?.toString().trim() ?? '';
        final rpcDoctorName = row['doctor_name']?.toString().trim() ?? '';
        final doctorName = rpcDoctorName.isEmpty
            ? null
            : (doctorTitle.isEmpty ? rpcDoctorName : '$doctorTitle $rpcDoctorName');
        final createdAtRaw = row['created_at']?.toString();
        final uploadedAt = DateTime.tryParse(createdAtRaw ?? '') ??
            DateTime.now().toUtc();
        final sections = row['sections'];
        if (sections is! List) continue;

        int idx = 0;
        for (final section in sections) {
          if (section is! Map) continue;
          if (section['type']?.toString() != 'attachments') continue;
          final value = section['value'];
          if (value is! List) continue;

          for (final att in value) {
            if (att is! Map) continue;
            final url = att['url']?.toString() ?? '';
            if (url.isEmpty) continue;

            final type = (att['type'] ?? att['file_type'] ?? '')
                .toString()
                .toLowerCase();
            final inferredPdf =
                type == 'pdf' || url.toLowerCase().endsWith('.pdf');
            final fileType = inferredPdf ? 'pdf' : 'image';
            final name = att['name']?.toString().isNotEmpty == true
                ? att['name'].toString()
                : 'Attachment';

            synthetic.add(
              UserDocument(
                id: 'report_${reportId}_$idx',
                userId: userId ?? '',
                name: name,
                type: fileType,
                fileType: fileType,
                patientId: relativeId ?? userId ?? '',
                previewUrl: url,
                pages: [url],
                uploadedAt: uploadedAt,
                uploadedById: doctorId ?? '',
                cameFromConversation: false,
                encrypted: att['encrypted'] == true,
                source: 'report',
                sourceDoctorId: doctorId,
                sourceDoctorName: doctorName,
                bucket: url.startsWith('http')
                    ? 'documents' // won't be used — http URL is direct
                    : (att['bucket']?.toString() ?? 'chat.attachments'),
              ),
            );
            idx++;
          }
        }
      }
      if (kDebugMode) {
        debugPrint(
            '📁 DocumentsService.fetchReportAttachments → synthesised ${synthetic.length} attachments');
      }
      return synthetic;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('❌ fetchReportAttachments failed: $e');
        debugPrint(st.toString());
      }
      return const [];
    }
  }

  Future<void> deleteDocument(String documentId, String userId) async {
    await _client
        .from('documents')
        .delete()
        .eq('id', documentId)
        .eq('user_id', userId);
  }

  Future<void> deleteFiles(List<String> urls) async {
    for (final url in urls) {
      try {
        final path = Uri.parse(url).path.split('/storage/v1/object/public/documents/').last;
        await _client.storage.from('documents').remove([path]);
      } catch (e) {
        // Log error
      }
    }
  }

  /// Subscribe to realtime updates for documents belonging to the current
  /// patient context.  We subscribe on `patient_id` in all cases (see
  /// [fetchDocuments] for the rationale).
  RealtimeChannel? subscribeToDocuments({
    String? userId,
    String? relativeId,
    required Function() onChange,
  }) {
    final subjectId = relativeId ?? userId;
    if (subjectId == null) return null;
    return _client
        .channel('public:documents:patient_id:$subjectId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'documents',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'patient_id',
            value: subjectId,
          ),
          callback: (payload) {
            onChange();
          },
        )
        .subscribe();
  }
}
