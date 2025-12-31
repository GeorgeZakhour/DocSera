import 'package:supabase_flutter/supabase_flutter.dart';

/// عنصر واحد من جدول medical_master
class MedicalMasterItem {
  final String id;
  final String category;
  final String? type;
  final String? referenceSystem;
  final String? referenceCode;
  final String nameEn;
  final String nameAr;
  final String? descriptionEn;
  final String? descriptionAr;
  final bool severityAllowed;

  MedicalMasterItem({
    required this.id,
    required this.category,
    this.type,
    this.referenceSystem,
    this.referenceCode,
    required this.nameEn,
    required this.nameAr,
    this.descriptionEn,
    this.descriptionAr,
    required this.severityAllowed,
  });

  factory MedicalMasterItem.fromMap(Map<String, dynamic> map) {
    return MedicalMasterItem(
      id: map['id'] as String,
      category: map['category'] as String,
      type: map['type'] as String?,
      referenceSystem: map['reference_system'] as String?,
      referenceCode: map['reference_code'] as String?,
      nameEn: map['name_en'] as String? ?? '',
      nameAr: map['name_ar'] as String? ?? '',
      descriptionEn: map['description_en'] as String?,
      descriptionAr: map['description_ar'] as String?,
      severityAllowed: map['severity_allowed'] as bool? ?? false,
    );
  }
}

/// سجل حساسيّة واحد للمريض (join بين patient_medical_records + medical_master)
class PatientAllergyRecord {
  final String id;
  final String patientId;
  final MedicalMasterItem master;
  final String? severity; // low / medium / high
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isConfirmed;
  final String? notesEn;
  final String? notesAr;

  // NEW FIELDS
  final String? source;          // "patient" | "doctor"
  final DateTime? createdAt;
  final DateTime? updatedAt;

  PatientAllergyRecord({
    required this.id,
    required this.patientId,
    required this.master,
    this.severity,
    this.startDate,
    this.endDate,
    required this.isConfirmed,
    this.notesEn,
    this.notesAr,
    this.source,
    this.createdAt,
    this.updatedAt,
  });

  factory PatientAllergyRecord.fromMap(Map<String, dynamic> map) {
    final masterMap = map['medical_master'] as Map<String, dynamic>? ?? {};

    return PatientAllergyRecord(
      id: map['id'] as String,
      patientId: map['patient_id'] as String,
      master: MedicalMasterItem.fromMap(masterMap),
      severity: map['severity'] as String?,
      startDate: map['start_date'] != null
          ? DateTime.parse(map['start_date'] as String)
          : null,
      endDate: map['end_date'] != null
          ? DateTime.parse(map['end_date'] as String)
          : null,
      isConfirmed: map['is_confirmed'] as bool? ?? false,
      notesEn: map['notes_en'] as String?,
      notesAr: map['notes_ar'] as String?,

      // NEW FIELDS — SAFE PARSING
      source: map['source'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }
}


/// Service مركّز جداً للتعامل مع الحساسيّات فقط
class MedicalRecordsService {
  final SupabaseClient _client;

  MedicalRecordsService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// helper لتجهيز select المشترك
  String get _allergySelectFields => '''
    id,
    category,
    type,
    reference_system,
    reference_code,
    name_en,
    name_ar,
    description_en,
    description_ar,
    severity_allowed
  ''';

  /// جلب كل حساسيّات المريض (مع join على medical_master) ومفلترة على category = 'allergy'
  Future<List<PatientAllergyRecord>> fetchPatientAllergies(
      String patientId) async {
    final response = await _client
        .from('patient_medical_records')
        .select('''
          id,
          patient_id,
          master_id,
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
            severity_allowed
          )
        ''')
        .eq('patient_id', patientId)
        .eq('medical_master.category', 'allergy')
        .order('created_at', ascending: true);

    final data = response as List<dynamic>;
    return data
        .map((row) => PatientAllergyRecord.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  /// البحث ضمن medical_master للحساسيّات فقط
  /// مفلتر دائماً على category = 'allergy' و is_active = true
  /// ملاحظة: لا نستخدم or() حتى نكون متوافقين مع نسخ supabase القديمة،
  /// لذلك ننفّذ استعلامين (name_en + name_ar) ونندمج النتيجة في Dart.
  Future<List<MedicalMasterItem>> searchAllergyMaster(String query) async {
    final trimmed = query.trim();

    List<dynamic> rows = [];

    if (trimmed.isEmpty) {
      // بدون فلتر نصي: نجيب ليميت بسيط 50 عنصر فقط
      rows = await _client
          .from('medical_master')
          .select(_allergySelectFields)
          .eq('category', 'allergy')
          .eq('is_active', true)
          .order('name_en', ascending: true)
          .limit(50);
    } else {
      final pattern = '%$trimmed%';

      // بحث حسب الإنجليزية
      final resEn = await _client
          .from('medical_master')
          .select(_allergySelectFields)
          .eq('category', 'allergy')
          .eq('is_active', true)
          .ilike('name_en', pattern)
          .order('name_en', ascending: true)
          .limit(30);

      // بحث حسب العربية
      final resAr = await _client
          .from('medical_master')
          .select(_allergySelectFields)
          .eq('category', 'allergy')
          .eq('is_active', true)
          .ilike('name_ar', pattern)
          .order('name_ar', ascending: true)
          .limit(30);

      // دمج + إزالة التكرار على مستوى id (بأقل تكلفة ممكنة)
      final seenIds = <String>{};
      final merged = <dynamic>[];

      for (final row in resEn) {
        final id = (row)['id'] as String;
        if (!seenIds.contains(id)) {
          seenIds.add(id);
          merged.add(row);
        }
      }

      for (final row in resAr) {
        final id = (row)['id'] as String;
        if (!seenIds.contains(id)) {
          seenIds.add(id);
          merged.add(row);
        }
      }

      rows = merged;
    }

    return rows
        .map((row) => MedicalMasterItem.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  /// إضافة سجل حساسيّة جديد للمريض
  Future<void> addPatientAllergy({
    required String patientId,
    required String masterId,
    String? severity,
    DateTime? startDate,
    DateTime? endDate,
    String? notes,
    required bool isArabicNotes,
  }) async {
    final insertMap = <String, dynamic>{
      'patient_id': patientId,
      'master_id': masterId,
      'source': 'patient',
      'is_confirmed': false,
      'severity': severity,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'notes_en': isArabicNotes ? null : notes,
      'notes_ar': isArabicNotes ? notes : null,
    };

    await _client.from('patient_medical_records').insert(insertMap);
  }

  /// حذف سجل حساسيّة
  Future<void> deletePatientAllergy(String recordId) async {
    await _client
        .from('patient_medical_records')
        .delete()
        .eq('id', recordId);
  }
}
