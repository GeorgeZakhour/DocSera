// Security tripwire for the deep-link token validator.
//
// Per docs/launch/05-security-review.md, deep-link tokens must be
// length-bounded and charset-restricted before reaching the DB.
// If this regex ever drifts, this test fails — and that's the point.

import 'package:flutter_test/flutter_test.dart';
import 'package:docsera/services/navigation/deep_link_service.dart';

void main() {
  group('isValidDoctorToken', () {
    test('accepts canonical short alphanumeric tokens', () {
      expect(isValidDoctorToken('abc123'), true);
      expect(isValidDoctorToken('Doctor_Sample-1'), true);
      expect(isValidDoctorToken('A'), true);
    });

    test('accepts hyphen and underscore', () {
      expect(isValidDoctorToken('a_b'), true);
      expect(isValidDoctorToken('a-b'), true);
      expect(isValidDoctorToken('-_-'), true);
    });

    test('rejects empty string', () {
      expect(isValidDoctorToken(''), false);
    });

    test('rejects tokens longer than 64 chars', () {
      expect(isValidDoctorToken('a' * 64), true);
      expect(isValidDoctorToken('a' * 65), false);
      expect(isValidDoctorToken('a' * 1024), false);
    });

    test('rejects SQL injection attempts', () {
      expect(isValidDoctorToken("abc' OR 1=1--"), false);
      expect(isValidDoctorToken('abc"; DROP TABLE doctors;--'), false);
    });

    test('rejects path traversal attempts', () {
      expect(isValidDoctorToken('../etc/passwd'), false);
      expect(isValidDoctorToken('..%2Fadmin'), false);
    });

    test('rejects URL-encoded payloads', () {
      expect(isValidDoctorToken('abc%20def'), false);
      expect(isValidDoctorToken('a%00b'), false);
    });

    test('rejects whitespace and control characters', () {
      expect(isValidDoctorToken('abc def'), false);
      expect(isValidDoctorToken('abc\tdef'), false);
      expect(isValidDoctorToken('abc\ndef'), false);
    });

    test('rejects unicode (Arabic, Cyrillic, emoji)', () {
      expect(isValidDoctorToken('طبيب'), false);
      expect(isValidDoctorToken('доктор'), false);
      expect(isValidDoctorToken('abc😀'), false);
    });

    test('rejects pathological mixed payloads', () {
      expect(isValidDoctorToken('valid-prefix\n<script>'), false);
      expect(isValidDoctorToken('javascript:alert(1)'), false);
    });
  });
}
