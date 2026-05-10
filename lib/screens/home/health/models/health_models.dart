class HealthMasterItem {
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
  final bool isVerified;

  HealthMasterItem({
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
    this.isVerified = true,
  });

  factory HealthMasterItem.fromMap(Map<String, dynamic> map) {
    return HealthMasterItem(
      id: map['id'],
      category: map['category'],
      type: map['type'],
      referenceSystem: map['reference_system'],
      referenceCode: map['reference_code'],
      nameEn: map['name_en'] ?? '',
      nameAr: map['name_ar'] ?? '',
      descriptionEn: map['description_en'],
      descriptionAr: map['description_ar'],
      severityAllowed: map['severity_allowed'] ?? false,
      isVerified: map['is_verified'] as bool? ?? true,
    );
  }
}

class HealthRecord {
  final String id;
  final String? patientId;        // FIXED: nullable
  final String? relativeId;       // NEW: must support relatives
  final HealthMasterItem master;
  final String? severity;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isConfirmed;
  final String? notesEn;
  final String? notesAr;
  final String? source;
  final DateTime createdAt;
  final DateTime? updatedAt;

  /// True when this row is the public face of multiple underlying
  /// patient_medical_records rows merged together (e.g., the patient
  /// + N doctors all having "asthma" attached to the same master_id).
  /// Set by HealthRecordsService.rollupByMaster — non-rollups keep
  /// the default value of 1 / null.
  final int mergedCount;

  /// IDs of every underlying row that this row represents. Used by the
  /// cubit's delete path to fan a single tap-to-delete out across
  /// every duplicate. The primary row's own id is included.
  final List<String> aggregatedIds;

  /// True when ANY underlying row was created by a doctor (source ==
  /// 'doctor' or non-null created_by_doctor_id). Drives the "confirmed
  /// by N doctors" UI affordance separately from is_confirmed.
  final bool hasDoctorSource;

  HealthRecord({
    required this.id,
    required this.patientId,
    required this.relativeId,
    required this.master,
    this.severity,
    this.startDate,
    this.endDate,
    required this.isConfirmed,
    this.notesEn,
    this.notesAr,
    this.source,
    required this.createdAt,
    this.updatedAt,
    this.mergedCount = 1,
    List<String>? aggregatedIds,
    bool? hasDoctorSource,
  })  : aggregatedIds = aggregatedIds ?? const [],
        hasDoctorSource = hasDoctorSource ?? (source == 'doctor');

  factory HealthRecord.fromMap(Map<String, dynamic> map) {
    final id = map['id'] as String;
    final source = map['source'] as String? ?? "patient";
    final hasDoctor = source == 'doctor' || map['created_by_doctor_id'] != null;
    return HealthRecord(
      id: id,
      patientId: map['patient_id'] as String?,         // FIXED
      relativeId: map['relative_id'] as String?,       // NEW

      master: HealthMasterItem.fromMap(map['medical_master'] ?? {}),

      severity: map['severity'] as String?,            // nullable
      startDate: map['start_date'] != null
          ? DateTime.parse(map['start_date'])
          : null,
      endDate: map['end_date'] != null
          ? DateTime.parse(map['end_date'])
          : null,

      isConfirmed: map['is_confirmed'] as bool? ?? false,

      notesEn: map['notes_en'] as String?,
      notesAr: map['notes_ar'] as String?,

      source: source,

      createdAt: DateTime.parse(map['created_at']),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'])
          : null,

      mergedCount: 1,
      aggregatedIds: [id],
      hasDoctorSource: hasDoctor,
    );
  }
}
