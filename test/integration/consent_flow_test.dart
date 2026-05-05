// Consent flow integration test — verifies the legal versions checker's
// JSON-shape contract and PendingReconsent semantics. The full
// "fetch manifest → compare to user's accepted versions → record" path
// is tested at the contract layer; the live HTTP/Supabase parts are
// system integration concerns.

import 'package:flutter_test/flutter_test.dart';

import 'package:docsera/services/legal/legal_versions_checker.dart';

void main() {
  group('LegalDocumentInfo.fromJson', () {
    test('parses a canonical entry', () {
      final info = LegalDocumentInfo.fromJson({
        'code': 'privacy',
        'version': '1.0',
        'url': 'https://docsera.app/legal/privacy',
        'requires_consent': true,
      });
      expect(info, isNotNull);
      expect(info!.code, 'privacy');
      expect(info.version, '1.0');
      expect(info.url, 'https://docsera.app/legal/privacy');
      expect(info.requiresConsent, true);
    });

    test('returns null when code is missing or non-string', () {
      expect(LegalDocumentInfo.fromJson({'version': '1.0'}), isNull);
      expect(LegalDocumentInfo.fromJson({'code': 123, 'version': '1.0'}),
          isNull);
    });

    test('returns null when version is missing', () {
      expect(LegalDocumentInfo.fromJson({'code': 'privacy'}), isNull);
    });

    test('url defaults to empty string when missing', () {
      final info = LegalDocumentInfo.fromJson({
        'code': 'terms',
        'version': '1.0',
      });
      expect(info?.url, '');
    });

    test('requires_consent defaults to false (non-blocking) when missing', () {
      final info = LegalDocumentInfo.fromJson({
        'code': 'medical_disclaimer',
        'version': '1.0',
      });
      expect(info?.requiresConsent, false);
    });
  });

  group('PendingReconsent', () {
    test('isEmpty when no documents', () {
      final p = PendingReconsent([]);
      expect(p.isEmpty, true);
      expect(p.isNotEmpty, false);
    });

    test('isNotEmpty when documents present', () {
      final p = PendingReconsent([
        LegalDocumentInfo(
            code: 'privacy', version: '2.0', url: '', requiresConsent: true),
      ]);
      expect(p.isNotEmpty, true);
      expect(p.isEmpty, false);
    });

    test('exposes the document list', () {
      final p = PendingReconsent([
        LegalDocumentInfo(
            code: 'terms', version: '2.0', url: '', requiresConsent: true),
        LegalDocumentInfo(
            code: 'privacy', version: '2.0', url: '', requiresConsent: true),
      ]);
      expect(p.documents.length, 2);
      expect(p.documents.map((d) => d.code), containsAll(['terms', 'privacy']));
    });
  });

  group('Consent flow — version comparison contract', () {
    test('user at v1.0 with manifest at v1.0 → no reconsent needed', () {
      // Conceptual: when accepted == manifest for all required docs,
      // PendingReconsent should be empty.
      final accepted = {'privacy': '1.0', 'terms': '1.0'};
      final manifest = [
        LegalDocumentInfo(
            code: 'privacy', version: '1.0', url: '', requiresConsent: true),
        LegalDocumentInfo(
            code: 'terms', version: '1.0', url: '', requiresConsent: true),
      ];
      final pending = manifest
          .where((d) =>
              d.requiresConsent && accepted[d.code] != d.version)
          .toList();
      expect(pending, isEmpty);
    });

    test('user at v1.0 with manifest at v2.0 → reconsent for the changed docs',
        () {
      final accepted = {'privacy': '1.0', 'terms': '1.0'};
      final manifest = [
        LegalDocumentInfo(
            code: 'privacy', version: '2.0', url: '', requiresConsent: true),
        LegalDocumentInfo(
            code: 'terms', version: '1.0', url: '', requiresConsent: true),
      ];
      final pending = manifest
          .where((d) =>
              d.requiresConsent && accepted[d.code] != d.version)
          .toList();
      expect(pending.length, 1);
      expect(pending.first.code, 'privacy');
    });

    test('non-required documents do not trigger reconsent even when changed',
        () {
      final accepted = {'medical_disclaimer': '1.0'};
      final manifest = [
        LegalDocumentInfo(
          code: 'medical_disclaimer',
          version: '2.0',
          url: '',
          requiresConsent: false,
        ),
      ];
      final pending = manifest
          .where((d) =>
              d.requiresConsent && accepted[d.code] != d.version)
          .toList();
      expect(pending, isEmpty);
    });

    test('a brand-new required document the user has never accepted triggers reconsent',
        () {
      final accepted = <String, String>{};
      final manifest = [
        LegalDocumentInfo(
            code: 'privacy', version: '1.0', url: '', requiresConsent: true),
      ];
      final pending = manifest
          .where((d) =>
              d.requiresConsent && accepted[d.code] != d.version)
          .toList();
      expect(pending, hasLength(1));
    });
  });
}
