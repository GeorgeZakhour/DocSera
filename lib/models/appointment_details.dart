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
  final String reason;
  final String clinicName; // ✅ إضافة اسم العيادة
  final Map<String, dynamic> clinicAddress;// ✅ إضافة عنوان العيادة

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
    required this.clinicName, // ✅ استلام اسم العيادة
    required this.clinicAddress, // ✅ استلام عنوان العيادة
  });

  // ✅ `copyWith` لتعديل أي بيانات عند الحاجة
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
    String? clinicName,
    Map<String, dynamic>? clinicAddress

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
      clinicName: clinicName ?? this.clinicName, // ✅ إضافة العيادة
      clinicAddress: clinicAddress ?? this.clinicAddress, // ✅ إضافة العنوان
    );
  }
}
