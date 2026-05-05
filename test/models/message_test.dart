// Round-trip tests for Message model.
//
// Schema drift between mobile and backend is a top crash cause.
// These tests pin the JSON shape so a backend rename or type change
// produces a CI failure here, not a runtime cast error in production.

import 'package:flutter_test/flutter_test.dart';
import 'package:docsera/models/message.dart';

import '../_helpers/fixtures.dart';
import '../_helpers/tz_init.dart';

void main() {
  setUpAll(initTzForTests);

  group('Message', () {
    test('fromMap parses canonical payload', () {
      final m = Message.fromMap(Fixtures.messageMap());
      expect(m.id, 'msg-1');
      expect(m.senderId, 'patient-1');
      expect(m.text, 'hello');
      expect(m.isSeen, false);
      expect(m.timestamp, isA<DateTime>());
    });

    test('toMap → fromMap is a stable round-trip for fields, not timestamp', () {
      // Timestamp goes through Syria-zone parsing which is not strictly
      // identity, so we don't compare it byte-for-byte. Everything else
      // must round-trip exactly.
      final original = Fixtures.message(
        id: 'abc',
        senderId: 'sender-x',
        text: 'roundtrip',
        isSeen: true,
      );
      final back = Message.fromMap(original.toMap());
      expect(back.id, original.id);
      expect(back.senderId, original.senderId);
      expect(back.text, original.text);
      expect(back.isSeen, original.isSeen);
    });

    test('fromMap tolerates missing optional fields', () {
      final m = Message.fromMap({
        'id': 1,
        'senderId': null,
        'text': null,
        'timestamp': null,
        'isSeen': null,
      });
      expect(m.id, '1');
      expect(m.senderId, '');
      expect(m.text, '');
      expect(m.isSeen, false);
      // timestamp falls back to "now" rather than crashing
      expect(m.timestamp, isA<DateTime>());
    });

    test('fromMap coerces non-string id to string', () {
      final m = Message.fromMap({
        'id': 42,
        'senderId': 's',
        'text': 't',
        'timestamp': DateTime.utc(2026, 1, 1).toIso8601String(),
        'isSeen': false,
      });
      expect(m.id, '42');
    });
  });
}
