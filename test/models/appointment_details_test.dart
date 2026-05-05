import 'package:flutter_test/flutter_test.dart';
import 'package:docsera/models/appointment_details.dart';

import '../_helpers/fixtures.dart';

void main() {
  group('AppointmentDetails', () {
    test('constructor populates required fields', () {
      final a = Fixtures.appointmentDetails(
        doctorName: 'Dr. House',
        patientName: 'John',
        reason: 'Check-up',
      );
      expect(a.doctorName, 'Dr. House');
      expect(a.patientName, 'John');
      expect(a.reason, 'Check-up');
      expect(a.isRelative, false);
      expect(a.newPatient, false);
      expect(a.location, isNull);
      expect(a.reasonId, isNull);
    });

    test('copyWith overrides only specified fields', () {
      final a = Fixtures.appointmentDetails();
      final b = a.copyWith(reason: 'Follow-up', patientAge: 45);
      expect(b.reason, 'Follow-up');
      expect(b.patientAge, 45);
      expect(b.doctorId, a.doctorId);
      expect(b.patientName, a.patientName);
    });

    test('copyWith with no args is equivalent', () {
      final a = Fixtures.appointmentDetails();
      final b = a.copyWith();
      expect(b.doctorId, a.doctorId);
      expect(b.patientId, a.patientId);
      expect(b.clinicName, a.clinicName);
    });

    test('copyWith preserves clinicAddress map structure', () {
      final a = Fixtures.appointmentDetails();
      final b = a.copyWith(
        clinicAddress: {'street': '99 New', 'city': 'Aleppo'},
      );
      expect(b.clinicAddress['city'], 'Aleppo');
      expect(b.clinicAddress['street'], '99 New');
    });
  });
}
