// Deep-link integration test — exercises the public token validator
// against URI shapes that DeepLinkService extracts from incoming links.

import 'package:flutter_test/flutter_test.dart';
import 'package:docsera/services/navigation/deep_link_service.dart';

void main() {
  group('DeepLink — token extraction patterns', () {
    test('docsera://doctor/<token> exposes the token in pathSegments[0]', () {
      final uri = Uri.parse('docsera://doctor/abc123');
      expect(uri.scheme, 'docsera');
      expect(uri.host, 'doctor');
      expect(uri.pathSegments.first, 'abc123');
      expect(isValidDoctorToken(uri.pathSegments.first), true);
    });

    test('https URL exposes the token in pathSegments[1]', () {
      final uri = Uri.parse('https://docsera.app/doctor/abc123');
      expect(uri.pathSegments[0], 'doctor');
      expect(uri.pathSegments[1], 'abc123');
      expect(isValidDoctorToken(uri.pathSegments[1]), true);
    });

    test('http URL is treated the same as https (legacy)', () {
      final uri = Uri.parse('http://docsera.app/doctor/abc123');
      expect(uri.scheme.startsWith('http'), true);
      expect(uri.pathSegments[1], 'abc123');
      expect(isValidDoctorToken(uri.pathSegments[1]), true);
    });

    test('extra path segments after the token are present (not auto-rejected)',
        () {
      final uri = Uri.parse('https://docsera.app/doctor/abc/extra');
      expect(uri.pathSegments[1], 'abc');
      expect(uri.pathSegments.length, 3);
      // The validator only sees pathSegments[1] in production code, so
      // 'extra' would never reach the DB.
      expect(isValidDoctorToken(uri.pathSegments[1]), true);
    });

    test('hostile token in a well-formed URL is rejected by the validator',
        () {
      final uri = Uri.parse(
        "https://docsera.app/doctor/abc';DROP%20TABLE%20doctors;--",
      );
      expect(isValidDoctorToken(uri.pathSegments[1]), false);
    });

    test('empty path on docsera:// scheme has no token to extract', () {
      final uri = Uri.parse('docsera://doctor/');
      // pathSegments may be empty or contain a single empty segment.
      final tokens = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      expect(tokens, isEmpty);
    });
  });
}
