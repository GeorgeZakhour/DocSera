class AppointmentDetails {
  final String doctorId;
  final String doctorName;
  final String doctorGender;
  final String doctorTitle;
  final String specialty;
  final String image;
  final String patientId;
  final bool isRelative;
  final String patientName;
  final String patientGender;
  final int patientAge;
  final bool newPatient;
  final String reason;              // النص
  final String? reasonId;           // 🆕 المعرّف (UUID أو string)
  final String clinicName;
  final Map<String, dynamic> clinicAddress;

  final Map<String, dynamic>? location; // 🆕 lat/lng كـ jsonb

  AppointmentDetails({
    required this.doctorId,
    required this.doctorName,
    required this.doctorGender,
    required this.doctorTitle,
    required this.specialty,
    required this.image,
    required this.patientId,
    required this.isRelative,
    required this.patientName,
    required this.patientGender,
    required this.patientAge,
    required this.newPatient,
    required this.reason,
    this.reasonId,                       // 🆕 optional
    required this.clinicName,
    required this.clinicAddress,
    this.location,                       // 🆕 optional
  });

  /// ✅ copyWith لتحديث أي قيمة بسهولة
  AppointmentDetails copyWith({
    String? doctorId,
    String? doctorName,
    String? doctorGender,
    String? doctorTitle,
    String? specialty,
    String? image,
    String? patientId,
    bool? isRelative,
    String? patientName,
    String? patientGender,
    int? patientAge,
    bool? newPatient,
    String? reason,
    String? reasonId,
    String? clinicName,
    Map<String, dynamic>? clinicAddress,
    Map<String, dynamic>? location,
  }) {
    return AppointmentDetails(
      doctorId: doctorId ?? this.doctorId,
      doctorName: doctorName ?? this.doctorName,
      doctorGender: doctorGender ?? this.doctorGender,
      doctorTitle: doctorTitle ?? this.doctorTitle,
      specialty: specialty ?? this.specialty,
      image: image ?? this.image,
      patientId: patientId ?? this.patientId,
      isRelative: isRelative ?? this.isRelative,
      patientName: patientName ?? this.patientName,
      patientGender: patientGender ?? this.patientGender,
      patientAge: patientAge ?? this.patientAge,
      newPatient: newPatient ?? this.newPatient,
      reason: reason ?? this.reason,
      reasonId: reasonId ?? this.reasonId,
      clinicName: clinicName ?? this.clinicName,
      clinicAddress: clinicAddress ?? this.clinicAddress,
      location: location ?? this.location,
    );
  }
}
