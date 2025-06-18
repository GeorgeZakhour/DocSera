class PatientProfile {
  final String patientId;
  final String doctorId;
  final String patientName;
  final String patientGender;
  final int patientAge;
  final String patientDOB;
  final String patientPhoneNumber;
  final String patientEmail;
  final String reason;

  PatientProfile({
    required this.patientId,
    required this.doctorId,
    required this.patientName,
    required this.patientGender,
    required this.patientAge,
    required this.patientDOB,
    required this.patientPhoneNumber,
    required this.patientEmail,
    required this.reason,
  });

  PatientProfile copyWith({
    String? patientId,
    String? doctorId,
    String? patientName,
    String? patientGender,
    int? patientAge,
    String? patientDOB,
    String? patientPhoneNumber,
    String? patientEmail,
    String? reason,
  }) {
    return PatientProfile(
      patientId: patientId ?? this.patientId,
      doctorId: doctorId ?? this.doctorId,
      patientName: patientName ?? this.patientName,
      patientGender: patientGender ?? this.patientGender,
      patientAge: patientAge ?? this.patientAge,
      patientDOB: patientDOB ?? this.patientDOB,
      patientPhoneNumber: patientPhoneNumber ?? this.patientPhoneNumber,
      patientEmail: patientEmail ?? this.patientEmail,
      reason: reason ?? this.reason,
    );
  }


  factory PatientProfile.fromMap(Map<String, dynamic> map) {
    return PatientProfile(
      patientId: map['userId'] ?? '',
      doctorId: map['doctorId'] ?? '',
      patientName: map['patientName'] ?? '',
      patientGender: map['userGender'] ?? '',
      patientAge: map['userAge'] ?? 0,
      patientDOB: '', // 🔸 مو موجود بالمصدر، حط قيمة مؤقتة أو احذف الحقل إذا مو مستخدم
      patientPhoneNumber: '', // 🔸 نفس الشيء
      patientEmail: '',
      reason: map['reason'] ?? '',
    );
  }

}
