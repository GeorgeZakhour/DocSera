// Smoke tests verifying icon constants used in OfflineBanner remain
// available (catches accidental SDK upgrades that rename or remove them).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Material icons used in critical UX', () {
    test('Icons.wifi_off_rounded resolves', () {
      expect(Icons.wifi_off_rounded, isA<IconData>());
    });

    test('Icons.wifi_rounded resolves', () {
      expect(Icons.wifi_rounded, isA<IconData>());
    });

    test('Icons.error_outline resolves', () {
      expect(Icons.error_outline, isA<IconData>());
    });

    test('Icons.check_circle resolves', () {
      expect(Icons.check_circle, isA<IconData>());
    });

    test('Icons.lock_outline resolves', () {
      expect(Icons.lock_outline, isA<IconData>());
    });
  });
}
