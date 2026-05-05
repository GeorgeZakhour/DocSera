// ErrorHandler.resolve maps raw errors to user-facing Arabic messages.
// Wrong mapping = wrong UX during a network outage. These tests pin
// each branch so a regression (e.g. a new exception type slipping
// through to the default) shows up immediately.

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:docsera/utils/error_handler.dart';

void main() {
  group('ErrorHandler.resolve', () {
    test('SocketException → no-internet message', () {
      final r = ErrorHandler.resolve(const SocketException('failed host lookup'));
      expect(r, contains('الإنترنت'));
    });

    test('"failed host lookup" string variant → no-internet message', () {
      final r = ErrorHandler.resolve(Exception('failed host lookup boom'));
      expect(r, contains('الإنترنت'));
    });

    test('http.ClientException → server connection message', () {
      final r = ErrorHandler.resolve(http.ClientException('boom'));
      expect(r, contains('الخادم'));
    });

    test('timeout substring → timeout message', () {
      final r = ErrorHandler.resolve(Exception('Connection timeout after 30s'));
      expect(r, contains('انتهت'));
    });

    test('PostgrestException → server error with code', () {
      final r = ErrorHandler.resolve(
        const PostgrestException(message: 'x', code: '23505'),
      );
      expect(r, contains('23505'));
    });

    test('huge stack trace falls back to default message', () {
      final huge = 'X' * 500;
      final r = ErrorHandler.resolve(Exception(huge));
      expect(r, 'حدث خطأ ما');
    });

    test('short unknown error appends to default', () {
      final r = ErrorHandler.resolve('something weird');
      expect(r, contains('something weird'));
      expect(r, startsWith('حدث خطأ ما'));
    });

    test('custom defaultMessage flows through', () {
      final r = ErrorHandler.resolve('x', defaultMessage: 'custom default');
      expect(r, startsWith('custom default'));
    });
  });
}
