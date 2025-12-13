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
  });

  factory HealthRecord.fromMap(Map<String, dynamic> map) {
    return HealthRecord(
      id: map['id'] as String,
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

      source: map['source'] as String? ?? "patient",

      createdAt: DateTime.parse(map['created_at']),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'])
          : null,
    );
  }
}
