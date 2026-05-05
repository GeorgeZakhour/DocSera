import 'package:flutter_test/flutter_test.dart';
import 'package:docsera/models/notes.dart';

import '../_helpers/fixtures.dart';
import '../_helpers/tz_init.dart';

void main() {
  setUpAll(initTzForTests);

  group('Note', () {
    test('fromMap parses canonical payload', () {
      final n = Note.fromMap(Fixtures.noteMap());
      expect(n.id, 'note-1');
      expect(n.title, 'Sample');
      expect(n.userId, 'user-1');
      expect(n.relativeId, isNull);
      expect(n.content, isA<List<dynamic>>());
    });

    test('relativeId round-trips when present', () {
      final n = Note.fromMap(Fixtures.noteMap(relativeId: 'rel-7'));
      expect(n.relativeId, 'rel-7');
      expect(n.toMap()['relative_id'], 'rel-7');
    });

    test('toMap omits relative_id when null (preserves storage shape)', () {
      final n = Fixtures.note();
      expect(n.toMap().containsKey('relative_id'), false);
    });

    test('copyWith updates title and content but preserves identity', () {
      final n = Fixtures.note(title: 'Old');
      final updated = n.copyWith(title: 'New');
      expect(updated.id, n.id);
      expect(updated.userId, n.userId);
      expect(updated.title, 'New');
    });

    test('fromMap tolerates missing content field', () {
      final n = Note.fromMap({
        'id': 'x',
        'title': 't',
        'created_at': DateTime.utc(2026, 1, 1).toIso8601String(),
        'user_id': 'u',
      });
      expect(n.content, isEmpty);
    });
  });
}
