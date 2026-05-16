import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:docsera/utils/color_utils.dart';

void main() {
  group('colorFromHex', () {
    test('parses 6-digit hex with leading #', () {
      final c = colorFromHex('#FF8F00');
      // Alpha should be FF when not provided.
      expect((c.a * 255.0).round() & 0xff, 0xFF);
      expect((c.r * 255.0).round() & 0xff, 0xFF);
      expect((c.g * 255.0).round() & 0xff, 0x8F);
      expect((c.b * 255.0).round() & 0xff, 0x00);
    });

    test('parses 6-digit hex without leading #', () {
      expect((colorFromHex('FF8F00').r * 255.0).round() & 0xff, 0xFF);
    });

    test('parses 8-digit hex (with alpha)', () {
      final c = colorFromHex('#80112233');
      expect((c.a * 255.0).round() & 0xff, 0x80);
      expect((c.r * 255.0).round() & 0xff, 0x11);
      expect((c.g * 255.0).round() & 0xff, 0x22);
      expect((c.b * 255.0).round() & 0xff, 0x33);
    });

    test('null returns fallback', () {
      const fallback = Color(0xFF112233);
      expect(colorFromHex(null, fallback: fallback), fallback);
    });

    test('empty string returns fallback', () {
      const fallback = Color(0xFF112233);
      expect(colorFromHex('', fallback: fallback), fallback);
    });

    test('default fallback is the brand teal', () {
      expect(colorFromHex(null), const Color(0xFF009092));
    });

    test('whitespace is trimmed', () {
      expect(colorFromHex('  #FF8F00  '), colorFromHex('#FF8F00'));
    });

    test('malformed hex (non-hex chars) returns fallback', () {
      const fallback = Color(0xFF112233);
      expect(colorFromHex('XXYYZZ', fallback: fallback), fallback);
    });

    test('wrong-length hex returns fallback', () {
      const fallback = Color(0xFF112233);
      expect(colorFromHex('#ABC', fallback: fallback), fallback);
      expect(colorFromHex('#ABCDE', fallback: fallback), fallback);
    });
  });
}
