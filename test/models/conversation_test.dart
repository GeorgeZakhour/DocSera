import 'package:flutter_test/flutter_test.dart';
import 'package:docsera/models/conversation.dart';

import '../_helpers/fixtures.dart';
import '../_helpers/tz_init.dart';

void main() {
  setUpAll(initTzForTests);

  group('Conversation', () {
    test('fromMap parses canonical payload', () {
      final c = Conversation.fromMap('conv-1', Fixtures.conversationMap());
      expect(c.id, 'conv-1');
      expect(c.patientId, 'patient-1');
      expect(c.doctorId, 'doctor-1');
      expect(c.lastMessage, 'hello');
      expect(c.lastSenderId, 'patient-1');
      expect(c.isClosed, false);
      expect(c.doctorName, 'Dr. Sample');
      expect(c.doctorSpecialty, 'Cardiology');
    });

    test('isClosed flag round-trips for closed conversations', () {
      final closed = Conversation.fromMap(
        'c',
        Fixtures.conversationMap(isClosed: true),
      );
      expect(closed.isClosed, true);
    });

    test('participants list contains both sides', () {
      final c = Conversation.fromMap('c', Fixtures.conversationMap());
      expect(c.participants, containsAll(['patient-1', 'doctor-1']));
    });
  });
}
