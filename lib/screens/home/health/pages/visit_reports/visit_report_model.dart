import 'package:supabase_flutter/supabase_flutter.dart';

class VisitReport {
  final String appointmentId;
  final DateTime date;
  final String doctorName;
  final String? diagnosis;
  final String? recommendation;
  final String? doctorSpecialty;
  final String? clinicName;
  final String? clinicAddress;
  final String? doctorGender;
  final String? doctorTitle;
  final String? doctorImagePath;


  VisitReport({
    required this.appointmentId,
    required this.date,
    required this.doctorName,
    this.diagnosis,
    this.recommendation,
    this.doctorSpecialty,
    this.clinicName,
    this.clinicAddress,
    this.doctorGender,
    this.doctorTitle,
    this.doctorImagePath,
  });

  factory VisitReport.fromMap(Map<String, dynamic> map) {
    final report = map["report"] ?? {};

    // clinic_address قد تأتي Map أو String
    String? clinicAddress;
    final addr = map["clinic_address"];
    if (addr is Map) {
      final city = addr["city"] as String?;
      final street = addr["street"] as String?;
      final parts = <String>[];
      if (city != null && city.isNotEmpty) parts.add(city);
      if (street != null && street.isNotEmpty) parts.add(street);
      clinicAddress = parts.join(" - ");
    } else if (addr is String) {
      clinicAddress = addr;
    }

    return VisitReport(
      appointmentId: map["id"],
      date: DateTime.parse(map["appointment_date"]),
      doctorName: map["doctor_name"] ?? "",
      doctorSpecialty: map["doctor_specialty"],
      clinicName: map["clinic"],
      clinicAddress: clinicAddress,
      diagnosis: report["diagnosis"],
      recommendation: report["recommendation"],

      // NEW FIELDS
      doctorGender: map["doctor_gender"],
      doctorTitle: map["doctor_title"],

      // doctor image path only
      doctorImagePath: map["doctor_image"],
    );
  }
}
