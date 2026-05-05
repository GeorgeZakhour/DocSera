// Round-trip tests for UserDocument.
//
// Documents carry encrypted-bytes flags and bucket routing — a regression
// here would route encrypted bytes to the wrong decryption path or load
// from the wrong storage bucket, producing silent corruption.

import 'package:flutter_test/flutter_test.dart';
import 'package:docsera/models/document.dart';

import '../_helpers/fixtures.dart';
import '../_helpers/tz_init.dart';

void main() {
  setUpAll(initTzForTests);

  group('UserDocument', () {
    test('fromMap parses canonical payload', () {
      final d = UserDocument.fromMap(Fixtures.documentMap());
      expect(d.id, 'doc-1');
      expect(d.userId, 'user-1');
      expect(d.name, 'Lab Result');
      expect(d.type, 'lab');
      expect(d.fileType, 'pdf');
      expect(d.encrypted, false);
      expect(d.source, 'patient');
      expect(d.bucket, 'documents');
      expect(d.fileSizeBytes, 1024);
      expect(d.pages, ['page-1']);
    });

    test('encrypted=true round-trips correctly', () {
      final encrypted = UserDocument.fromMap(
        Fixtures.documentMap(encrypted: true),
      );
      expect(encrypted.encrypted, true);
      // toMap only emits the key when encrypted is true
      expect(encrypted.toMap()['encrypted'], true);
    });

    test('toMap omits encrypted key when false (storage-side default)', () {
      final m = Fixtures.document(encrypted: false).toMap();
      expect(m.containsKey('encrypted'), false);
    });

    test('default bucket is "documents" when missing', () {
      final m = UserDocument.fromMap({
        'id': 'd',
        'user_id': 'u',
        'name': 'n',
        'type': 't',
        'file_type': 'pdf',
        'patient_id': 'p',
        'preview_url': '',
        'pages': [],
        'uploaded_at': DateTime.utc(2026, 1, 1).toIso8601String(),
        'uploaded_by_id': 'u',
      });
      expect(m.bucket, 'documents');
    });

    test('fileSizeBytes coerces num to int', () {
      final m = UserDocument.fromMap({
        ...Fixtures.documentMap(),
        'file_size_bytes': 2048.0,
      });
      expect(m.fileSizeBytes, 2048);
    });

    test('pages list defaults to empty when null', () {
      final m = UserDocument.fromMap({
        ...Fixtures.documentMap(),
        'pages': null,
      });
      expect(m.pages, isEmpty);
    });

    test('source field round-trips for doctor_added and report variants', () {
      for (final s in ['patient', 'doctor_added', 'report']) {
        final d = UserDocument.fromMap(Fixtures.documentMap(source: s));
        expect(d.source, s);
        expect(d.toMap()['source'], s);
      }
    });

    test('isStoragePath identifies non-http paths', () {
      final d = Fixtures.document();
      expect(d.isStoragePath('users/abc/file.pdf'), true);
      expect(d.isStoragePath('https://example.com/x.pdf'), false);
      expect(d.isStoragePath('http://example.com/x.pdf'), false);
    });
  });
}
