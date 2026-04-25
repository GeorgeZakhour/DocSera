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
}
