import 'package:flutter_test/flutter_test.dart';
import 'package:docsera/models/patient_profile.dart';

void main() {
  group('PatientProfile', () {
    Map<String, dynamic> map() => {
          'userId': 'p1',
          'doctorId': 'd1',
          'patientName': 'John',
          'userGender': 'male',
          'userAge': 30,
          'userDOB': '1996-05-05',
          'userPhoneNumber': '+963 11 1234567',
          'userEmail': 'john@example.com',
          'reason': 'Consultation',
        };

    test('fromMap parses fields it tracks (id/name/gender/age/reason)', () {
      // Note: fromMap deliberately doesn't read DOB/phone/email — those
      // come from a different source. Tracked here so a refactor that
      // wires them up is a deliberate decision, not a silent change.
      final p = PatientProfile.fromMap(map());
      expect(p.patientId, 'p1');
      expect(p.doctorId, 'd1');
      expect(p.patientName, 'John');
      expect(p.patientGender, 'male');
      expect(p.patientAge, 30);
      expect(p.reason, 'Consultation');
      expect(p.patientEmail, '');
      expect(p.patientPhoneNumber, '');
      expect(p.patientDOB, '');
    });

    test('fromMap tolerates missing fields with defaults', () {
      final p = PatientProfile.fromMap({});
      expect(p.patientId, '');
      expect(p.patientName, '');
      expect(p.patientAge, 0);
    });

    test('copyWith overrides only specified fields', () {
      final p = PatientProfile.fromMap(map());
      final updated = p.copyWith(patientAge: 31, reason: 'Follow-up');
      expect(updated.patientAge, 31);
      expect(updated.reason, 'Follow-up');
      // Untouched fields remain
      expect(updated.patientName, 'John');
      expect(updated.patientId, 'p1');
    });

    test('copyWith with no args returns equivalent instance', () {
      final p = PatientProfile.fromMap(map());
      final clone = p.copyWith();
      expect(clone.patientId, p.patientId);
      expect(clone.patientName, p.patientName);
      expect(clone.patientAge, p.patientAge);
    });
  });
}
