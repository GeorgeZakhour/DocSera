class ModularReportSection {
  final String type;
  final String key;
  final String? label;
  final dynamic value;
  final Map<String, dynamic>? config;
  final bool patientVisible;

  ModularReportSection({
    required this.type,
    required this.key,
    this.label,
    this.value,
    this.config,
    this.patientVisible = false,
  });

  factory ModularReportSection.fromJson(Map<String, dynamic> json) {
    return ModularReportSection(
      type: json['type'] ?? '',
      key: json['key'] ?? '',
      label: json['label'] as String?,
      value: json['value'],
      config: (json['config'] as Map?)?.cast<String, dynamic>(),
      patientVisible: json['patient_visible'] == true,
    );
  }

  bool get hasContent {
    if (value == null) return false;
    if (value is String) return value.toString().trim().isNotEmpty;
    if (value is List) return (value as List).isNotEmpty;
    if (value is Map) return (value as Map).isNotEmpty;
    return true;
  }
}

class ModularReport {
  final String id;
  final String? appointmentId;
  final String doctorId;
  final String? patientName;
  final String shareMode;
  final List<String>? patientVisibleSections;
  final List<ModularReportSection> sections;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Denormalized doctor info
  final String? doctorName;
  final String? doctorSpecialty;
  final String? doctorClinic;
  final String? doctorImage;
  final String? doctorGender;
  final String? doctorTitle;

  ModularReport({
    required this.id,
    this.appointmentId,
    required this.doctorId,
    this.patientName,
    required this.shareMode,
    this.patientVisibleSections,
    required this.sections,
    required this.createdAt,
    required this.updatedAt,
    this.doctorName,
    this.doctorSpecialty,
    this.doctorClinic,
    this.doctorImage,
    this.doctorGender,
    this.doctorTitle,
  });

  factory ModularReport.fromJson(Map<String, dynamic> json) {
    final sectionsJson = json['sections'] as List<dynamic>? ?? [];
    final visibleKeys = (json['patient_visible_sections'] as List<dynamic>?)
        ?.map((e) => e.toString()).toList();
    final shareMode = json['share_mode']?.toString() ?? 'full';

    // Filter sections based on share mode
    List<ModularReportSection> parsedSections = sectionsJson
        .map((e) => ModularReportSection.fromJson(e as Map<String, dynamic>))
        .where((s) => s.hasContent)
        .toList();

    if (shareMode == 'patient_friendly' && visibleKeys != null) {
      parsedSections = parsedSections.where((s) => visibleKeys.contains(s.key)).toList();
    }

    return ModularReport(
      id: json['id'] ?? '',
      appointmentId: json['appointment_id'],
      doctorId: json['doctor_id'] ?? '',
      patientName: json['patient_name'],
      shareMode: shareMode,
      patientVisibleSections: visibleKeys,
      sections: parsedSections,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      doctorName: json['doctor_name'],
      doctorSpecialty: json['doctor_specialty'],
      doctorClinic: json['doctor_clinic'],
      doctorImage: json['doctor_image'],
      doctorGender: json['doctor_gender'],
      doctorTitle: json['doctor_title'],
    );
  }
}
