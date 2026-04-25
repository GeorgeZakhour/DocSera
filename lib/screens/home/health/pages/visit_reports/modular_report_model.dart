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

  /// True when the server stripped this section's heavy value
  /// (body_map / image_comparison) to save bandwidth on list queries.
  bool get isHeavyPlaceholder => value == '__heavy__';

  /// Whether this section type carries heavy data (SVG/base64).
  bool get isHeavyType => type == 'body_map' || type == 'image_comparison';

  /// Returns a copy with the value replaced by a lightweight placeholder.
  ModularReportSection withStrippedValue() {
    return ModularReportSection(
      type: type,
      key: key,
      label: label,
      value: '__heavy__',
      config: config,
      patientVisible: patientVisible,
    );
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
  final String? doctorCity;
  final String? doctorImage;
  final String? doctorGender;
  final String? doctorTitle;
  final List<dynamic>? doctorPhones;
  final String? doctorMobile;
  final String? doctorEmail;
  final String? doctorWebsite;

  // Patient info
  final String? patientGender;
  final String? patientDob;
  final String? patientPhone;

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
    this.doctorCity,
    this.doctorImage,
    this.doctorGender,
    this.doctorTitle,
    this.doctorPhones,
    this.doctorMobile,
    this.doctorEmail,
    this.doctorWebsite,
    this.patientGender,
    this.patientDob,
    this.patientPhone,
  });

  /// Whether any section has a stripped heavy placeholder that needs lazy-loading.
  bool get hasHeavySections => sections.any((s) => s.isHeavyPlaceholder);

  /// Returns a copy with updated sections (used when merging lazy-loaded data).
  ModularReport copyWithSections(List<ModularReportSection> newSections) {
    return ModularReport(
      id: id,
      appointmentId: appointmentId,
      doctorId: doctorId,
      patientName: patientName,
      shareMode: shareMode,
      patientVisibleSections: patientVisibleSections,
      sections: newSections,
      createdAt: createdAt,
      updatedAt: updatedAt,
      doctorName: doctorName,
      doctorSpecialty: doctorSpecialty,
      doctorClinic: doctorClinic,
      doctorCity: doctorCity,
      doctorImage: doctorImage,
      doctorGender: doctorGender,
      doctorTitle: doctorTitle,
      doctorPhones: doctorPhones,
      doctorMobile: doctorMobile,
      doctorEmail: doctorEmail,
      doctorWebsite: doctorWebsite,
      patientGender: patientGender,
      patientDob: patientDob,
      patientPhone: patientPhone,
    );
  }

  /// Creates a report from JSON, optionally stripping heavy section values
  /// client-side (used by direct query fallback to match RPC behavior).
  factory ModularReport.fromJson(Map<String, dynamic> json, {bool stripHeavy = false}) {
    final sectionsJson = json['sections'] as List<dynamic>? ?? [];
    final visibleKeys = (json['patient_visible_sections'] as List<dynamic>?)
        ?.map((e) => e.toString()).toList();
    final shareMode = json['share_mode']?.toString() ?? 'full';

    // Filter sections based on share mode
    List<ModularReportSection> parsedSections = sectionsJson
        .map((e) => ModularReportSection.fromJson(e as Map<String, dynamic>))
        .where((s) => s.hasContent)
        .toList();

    // Client-side stripping for fallback path (mirrors fn_strip_heavy_sections)
    if (stripHeavy) {
      parsedSections = parsedSections
          .map((s) => s.isHeavyType ? s.withStrippedValue() : s)
          .toList();
    }

    if ((shareMode == 'patient_friendly' || shareMode == 'prescription') && visibleKeys != null) {
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
      doctorCity: json['doctor_city']?.toString(),
      doctorImage: json['doctor_image'],
      doctorGender: json['doctor_gender'],
      doctorTitle: json['doctor_title'],
      doctorPhones: json['doctor_phone'] is List ? json['doctor_phone'] : null,
      doctorMobile: json['doctor_mobile']?.toString(),
      doctorEmail: json['doctor_email']?.toString(),
      doctorWebsite: json['doctor_website']?.toString(),
      patientGender: json['patient_gender'],
      patientDob: json['patient_dob'],
      patientPhone: json['patient_phone'],
    );
  }
}
