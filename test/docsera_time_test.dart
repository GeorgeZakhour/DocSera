import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:docsera/utils/time_utils.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:flutter_localizations/flutter_localizations.dart';

void main() {
  setUpAll(() {
    initializeTimeZonesOnce();
  });

  group('DocSeraTime Tests (Syria Standard)', () {
    test('nowSyria should be UTC+3', () {
      final syriaNow = DocSeraTime.nowSyria();
      // Calculate offset in hours
      final offset = syriaNow.timeZoneOffset.inHours;
      expect(offset, 3, reason: "Syria must be UTC+3");
    });

    test('toSyria converts UTC correctly', () {
      // 12:00 PM UTC -> 03:00 PM Syria
      final utc = DateTime.utc(2026, 5, 5, 12, 0); 
      final syria = DocSeraTime.toSyria(utc);
      
      expect(syria.hour, 15);
      expect(syria.minute, 0);
    });

    test('tryParseToSyria handles parsing', () {
      final syria = DocSeraTime.tryParseToSyria("2026-05-05T12:00:00Z");
      expect(syria, isNotNull);
      expect(syria!.hour, 15); // 12 UTC -> 15 Syria
    });
  });
}
