// Extended DocSeraTime tests — covers edge cases the existing
// docsera_time_test.dart doesn't: parse failures, near-midnight,
// DST-stable Syria zone (no DST since 2022), and toUtc round-trips.

import 'package:flutter_test/flutter_test.dart';

import 'package:docsera/utils/time_utils.dart';

import '../_helpers/tz_init.dart';

void main() {
  setUpAll(initTzForTests);

  group('DocSeraTime — parsing edge cases', () {
    test('tryParseToSyria returns null for malformed input', () {
      expect(DocSeraTime.tryParseToSyria('not a date'), isNull);
      expect(DocSeraTime.tryParseToSyria(''), isNull);
    });

    test('tryParseToSyria handles ISO 8601 with Z suffix', () {
      final t = DocSeraTime.tryParseToSyria('2026-05-05T12:00:00Z');
      expect(t, isNotNull);
    });

    test('tryParseToSyria handles ISO 8601 without timezone', () {
      final t = DocSeraTime.tryParseToSyria('2026-05-05T12:00:00');
      expect(t, isNotNull);
    });
  });

  group('DocSeraTime — UTC round-trips', () {
    test('toUtc returns a UTC DateTime', () {
      final syria = DocSeraTime.tryParseToSyria('2026-05-05T12:00:00Z')!;
      final utc = DocSeraTime.toUtc(syria);
      expect(utc.isUtc, true);
    });

    test('Syria → UTC is reversible (within 1 second)', () {
      final original = DateTime.utc(2026, 5, 5, 12, 0);
      final syria = DocSeraTime.toSyria(original);
      final back = DocSeraTime.toUtc(syria);
      expect(back.isUtc, true);
      expect(back.difference(original).inSeconds.abs(), lessThan(2));
    });
  });

  group('DocSeraTime — boundaries', () {
    test('midnight UTC → 03:00 Syria', () {
      final utc = DateTime.utc(2026, 5, 5, 0, 0);
      final syria = DocSeraTime.toSyria(utc);
      expect(syria.hour, 3);
    });

    test('21:00 UTC crosses date boundary into Syria next day', () {
      final utc = DateTime.utc(2026, 5, 5, 21, 30);
      final syria = DocSeraTime.toSyria(utc);
      expect(syria.day, 6);
      expect(syria.hour, 0);
      expect(syria.minute, 30);
    });

    test('Syria has no DST (offset stable in summer and winter)', () {
      final summer = DocSeraTime.toSyria(DateTime.utc(2026, 7, 15, 12, 0));
      final winter = DocSeraTime.toSyria(DateTime.utc(2026, 1, 15, 12, 0));
      expect(summer.timeZoneOffset.inHours, 3);
      expect(winter.timeZoneOffset.inHours, 3);
    });
  });

  group('DocSeraTime — nowSyria / nowUtc', () {
    test('nowSyria returns a UTC+3 instant', () {
      final n = DocSeraTime.nowSyria();
      expect(n.timeZoneOffset.inHours, 3);
    });

    test('nowUtc returns a UTC instant', () {
      final n = DocSeraTime.nowUtc();
      expect(n.isUtc, true);
    });

    test('nowSyria and nowUtc produce instants within 1 second of each other',
        () {
      final s = DocSeraTime.nowSyria();
      final u = DocSeraTime.nowUtc();
      // The instant they describe is the same; only the displayed
      // wall-clock differs. Compare via toUtc().
      expect(DocSeraTime.toUtc(s).difference(u).inSeconds.abs(),
          lessThanOrEqualTo(1));
    });
  });
}
