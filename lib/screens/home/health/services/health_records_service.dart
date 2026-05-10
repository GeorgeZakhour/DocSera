import 'package:docsera/screens/home/health/models/health_models.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HealthRecordsService {
  final SupabaseClient _client;

  HealthRecordsService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// SELECT fields for master table
  String get _selectMasterFields => '''
    id,
    category,
    type,
    reference_system,
    reference_code,
    name_en,
    name_ar,
    description_en,
    description_ar,
    severity_allowed,
    is_verified
  ''';

  // ------------------------------------------------------------------
  // FETCH RECORDS (supports user + relative)
  // ------------------------------------------------------------------
  Future<List<HealthRecord>> fetchRecords({
    required String? userId,
    required String? relativeId,
    required String category,
  }) async {
    debugPrint("FETCH RECORDS → userId=$userId relativeId=$relativeId category=$category");

    if (userId == null && relativeId == null) {
      debugPrint("❌ FETCH RECORDS aborted: both userId and relativeId are null");
      return [];
    }

    final filterColumn = (relativeId != null) ? 'relative_id' : 'patient_id';
    final filterValue = (relativeId != null) ? relativeId : userId;

    debugPrint("➡ Using filter: $filterColumn = $filterValue");

    final response = await _client
        .from('patient_medical_records')
        .select('''
        id,
        patient_id,
        relative_id,
        severity,
        start_date,
        end_date,
        is_confirmed,
        notes_en,
        notes_ar,
        source,
        created_at,
        updated_at,
        medical_master!inner(
          id,
          category,
          type,
          reference_system,
          reference_code,
          name_en,
          name_ar,
          description_en,
          description_ar,
          severity_allowed,
          is_verified
        )
      ''')
        .eq(filterColumn, filterValue!)
        .filter('medical_master.category', 'eq', category)
        .order('created_at', ascending: true);

    debugPrint("✅ FETCH RECORDS RESULT → ${response.length} rows");

    return (response as List<dynamic>)
        .map((row) => HealthRecord.fromMap(row))
        .toList();
  }


  // ------------------------------------------------------------------
  // SEARCH master table
  // ------------------------------------------------------------------
  Future<List<HealthMasterItem>> searchMaster(String category, String query) async {
    final trimmed = query.trim();

    if (trimmed.isEmpty) {
      final rows = await _client
          .from('medical_master')
          .select(_selectMasterFields)
          .eq('category', category)
          .eq('is_active', true)
          .order('name_en')
          .limit(50);

      return rows.map((r) => HealthMasterItem.fromMap(r)).toList();
    }

    final pattern = '%$trimmed%';

    final en = await _client
        .from('medical_master')
        .select(_selectMasterFields)
        .eq('category', category)
        .eq('is_active', true)
        .ilike('name_en', pattern)
        .limit(30);

    final ar = await _client
        .from('medical_master')
        .select(_selectMasterFields)
        .eq('category', category)
        .eq('is_active', true)
        .ilike('name_ar', pattern)
        .limit(30);

    // دمج النتائج بدون تكرار
    final merged = <Map<String, dynamic>>[];
    final ids = <String>{};

    for (var row in [...en, ...ar]) {
      final id = row['id'];
      if (!ids.contains(id)) {
        ids.add(id);
        merged.add(row);
      }
    }

    return merged.map((r) => HealthMasterItem.fromMap(r)).toList();
  }

  // ------------------------------------------------------------------
  // ADD RECORD (supports userId or relativeId)
  // ------------------------------------------------------------------
  Future<void> addRecord({
    required String category,
    required String masterId,
    required String? userId,
    required String? relativeId,
    String? severity,
    DateTime? startDate,
    String? notes,
    required bool isArabicNotes,
  }) async {
    if (userId == null && relativeId == null) {
      throw Exception("No target patient defined.");
    }

    await _client.from('patient_medical_records').insert({
      'patient_id': userId,      // null إذا قريب
      'relative_id': relativeId, // null إذا مستخدم رئيسي
      'master_id': masterId,
      'severity': severity,
      'start_date': startDate?.toIso8601String(),
      'source': 'patient',
      'is_confirmed': false,
      'notes_en': isArabicNotes ? null : notes,
      'notes_ar': isArabicNotes ? notes : null,
    });
  }

  // ------------------------------------------------------------------
  // UPDATE RECORD (severity / start_date / notes — all optional)
  // ------------------------------------------------------------------
  /// Updates a single `patient_medical_records` row. Pass [setSeverity] /
  /// [setStartDate] = true with a null value to explicitly clear the
  /// field (vs. omitting which leaves it untouched).
  Future<void> updateRecord({
    required String id,
    String? severity,
    bool setSeverity = false,
    DateTime? startDate,
    bool setStartDate = false,
    String? notes,
    bool setNotes = false,
    required bool isArabicNotes,
  }) async {
    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (setSeverity) {
      updates['severity'] = severity;
    }
    if (setStartDate) {
      updates['start_date'] = startDate?.toIso8601String();
    }
    if (setNotes) {
      updates['notes_en'] = isArabicNotes ? null : notes;
      updates['notes_ar'] = isArabicNotes ? notes : null;
    }
    await _client
        .from('patient_medical_records')
        .update(updates)
        .eq('id', id);
  }

  // ------------------------------------------------------------------
  // CREATE CUSTOM MASTER ITEM (for manual entry)
  // ------------------------------------------------------------------
  Future<HealthMasterItem> createCustomMasterItem({
    required String category,
    required String nameEn,
    required String nameAr,
    String? descriptionEn,
    String? descriptionAr,
  }) async {
    final row = await _client.from('medical_master').insert({
      'category': category,
      'name_en': nameEn,
      'name_ar': nameAr,
      'description_en': descriptionEn,
      'description_ar': descriptionAr,
      'severity_allowed': true,
      'is_active': true,
      'is_verified': false,
      'source': 'patient',
      'created_by': _client.auth.currentUser?.id,
    }).select(_selectMasterFields).single();

    return HealthMasterItem.fromMap(row);
  }

  // ------------------------------------------------------------------
  // DELETE RECORD
  // ------------------------------------------------------------------
  Future<void> deleteRecord(String id) async {
    await _client.from('patient_medical_records').delete().eq('id', id);
  }

  /// Deletes every row in [ids] in a single round-trip — used by the
  /// rolled-up display path so a tap on one visible row removes all the
  /// underlying duplicates that share the same master_id.
  Future<void> deleteRecords(List<String> ids) async {
    if (ids.isEmpty) return;
    await _client.from('patient_medical_records').delete().inFilter('id', ids);
  }

  // ------------------------------------------------------------------
  // ROLLUP — display-layer dedup
  // ------------------------------------------------------------------
  // After a multi-doctor merge, the same condition (master_id) can
  // appear N times in patient_medical_records — once per doctor that
  // had it on their manual record, plus optionally once that the
  // patient self-entered. Each row is technically correct ("Dr X
  // confirmed asthma"), but the user reads it as 4 redundant "asthma"
  // entries.
  //
  // This helper groups by master.id and emits ONE rolled-up
  // HealthRecord per condition. Rules per group:
  //   * Primary id = the doctor-confirmed row if any exists, else the
  //     most recent. Edit operations on the displayed row target this
  //     primary.
  //   * `aggregatedIds` = every underlying row's id, so the cubit's
  //     delete path can fan out via deleteRecords([...]).
  //   * `isConfirmed` = OR across rows (any doctor confirming wins).
  //   * `hasDoctorSource` = OR across rows.
  //   * `mergedCount` = group size; UI uses this to render a "Confirmed
  //     by N doctors" badge when >1.
  //   * severity = highest of {low, medium, high} present.
  //   * notesEn / notesAr = first non-empty. Concatenating multiple
  //     doctors' notes risked making the UI noisy; v1 picks one.
  //   * startDate = earliest non-null; endDate = latest non-null.
  //   * createdAt = earliest; updatedAt = latest.
  //
  // No DB change — the underlying rows stay intact (so doctor-side
  // views, audits, and analytics continue to see each row as itself).
  static List<HealthRecord> rollupByMaster(List<HealthRecord> records) {
    if (records.length < 2) return records;
    final byMaster = <String, List<HealthRecord>>{};
    for (final r in records) {
      byMaster.putIfAbsent(r.master.id, () => []).add(r);
    }
    final out = <HealthRecord>[];
    for (final group in byMaster.values) {
      if (group.length == 1) {
        out.add(group.first);
        continue;
      }
      out.add(_mergeGroup(group));
    }
    // Preserve original order — keep the earliest createdAt at the top.
    out.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return out;
  }

  static HealthRecord _mergeGroup(List<HealthRecord> group) {
    // Pick the primary: first prefer doctor-confirmed; among ties take
    // the most recently updated/created. This becomes the row whose id
    // is exposed for edit operations.
    HealthRecord primary = group.first;
    for (final r in group) {
      final isCandidateConfirmed = r.isConfirmed && !primary.isConfirmed;
      final isCandidateNewer = r.isConfirmed == primary.isConfirmed &&
          (r.updatedAt ?? r.createdAt).isAfter(primary.updatedAt ?? primary.createdAt);
      if (isCandidateConfirmed || isCandidateNewer) {
        primary = r;
      }
    }

    final aggregatedIds = group.map((r) => r.id).toList(growable: false);
    final isConfirmed = group.any((r) => r.isConfirmed);
    final hasDoctor = group.any((r) => r.hasDoctorSource);

    String? mergedNotesEn = primary.notesEn;
    String? mergedNotesAr = primary.notesAr;
    if ((mergedNotesEn == null || mergedNotesEn.isEmpty)) {
      for (final r in group) {
        if (r.notesEn != null && r.notesEn!.isNotEmpty) {
          mergedNotesEn = r.notesEn;
          break;
        }
      }
    }
    if ((mergedNotesAr == null || mergedNotesAr.isEmpty)) {
      for (final r in group) {
        if (r.notesAr != null && r.notesAr!.isNotEmpty) {
          mergedNotesAr = r.notesAr;
          break;
        }
      }
    }

    DateTime? earliestStart;
    DateTime? latestEnd;
    for (final r in group) {
      if (r.startDate != null &&
          (earliestStart == null || r.startDate!.isBefore(earliestStart))) {
        earliestStart = r.startDate;
      }
      if (r.endDate != null &&
          (latestEnd == null || r.endDate!.isAfter(latestEnd))) {
        latestEnd = r.endDate;
      }
    }

    String? topSeverity = primary.severity;
    const order = {'low': 1, 'medium': 2, 'high': 3};
    int currentRank = order[topSeverity ?? ''] ?? 0;
    for (final r in group) {
      final rank = order[r.severity ?? ''] ?? 0;
      if (rank > currentRank) {
        topSeverity = r.severity;
        currentRank = rank;
      }
    }

    DateTime earliestCreated = primary.createdAt;
    DateTime? latestUpdated = primary.updatedAt;
    for (final r in group) {
      if (r.createdAt.isBefore(earliestCreated)) earliestCreated = r.createdAt;
      if (r.updatedAt != null &&
          (latestUpdated == null || r.updatedAt!.isAfter(latestUpdated))) {
        latestUpdated = r.updatedAt;
      }
    }

    return HealthRecord(
      id: primary.id,
      patientId: primary.patientId,
      relativeId: primary.relativeId,
      master: primary.master,
      severity: topSeverity,
      startDate: earliestStart,
      endDate: latestEnd,
      isConfirmed: isConfirmed,
      notesEn: mergedNotesEn,
      notesAr: mergedNotesAr,
      source: primary.source,
      createdAt: earliestCreated,
      updatedAt: latestUpdated,
      mergedCount: group.length,
      aggregatedIds: aggregatedIds,
      hasDoctorSource: hasDoctor,
    );
  }
}
