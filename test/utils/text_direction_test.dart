// detectTextDirection routes user input (search queries, message
// composition) to the right RTL/LTR rendering path. A regression here
// puts Arabic text in left-to-right boxes, which is jarring and
// fundamentally broken for our default-Arabic UX.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:docsera/utils/text_direction_utils.dart';

void main() {
  group('detectTextDirection', () {
    test('empty string → LTR (safe default)', () {
      expect(detectTextDirection(''), TextDirection.ltr);
    });

    test('English text → LTR', () {
      expect(detectTextDirection('Hello'), TextDirection.ltr);
      expect(detectTextDirection('Doctor Sample'), TextDirection.ltr);
    });

    test('Arabic text → RTL', () {
      expect(detectTextDirection('مرحبا'), TextDirection.rtl);
      expect(detectTextDirection('طبيب'), TextDirection.rtl);
    });

    test('numeric leading character → LTR', () {
      expect(detectTextDirection('123'), TextDirection.ltr);
    });

    test('symbol leading character → LTR (numbers/symbols are not Arabic)', () {
      expect(detectTextDirection('+963 11 1234567'), TextDirection.ltr);
    });

    test('Arabic followed by English → RTL (only first char matters)', () {
      expect(detectTextDirection('مرحبا hello'), TextDirection.rtl);
    });
  });
}
