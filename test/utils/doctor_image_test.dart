// getDoctorImage decides which fallback image (or remote URL) to render
// for a doctor card. Coverage matters because:
//   - Wrong gendered fallback is jarring UX
//   - "null"/empty URL handling regression would 404 every doctor card
//   - Arabic+English title forms must both be recognized

import 'package:flutter_test/flutter_test.dart';
import 'package:docsera/utils/doctor_image_utils.dart';

void main() {
  group('getDoctorImage', () {
    test('valid imageUrl is returned as-is', () {
      final r = getDoctorImage(
        imageUrl: 'https://x/y.png',
        gender: 'male',
        title: 'Dr.',
      );
      expect(r, 'https://x/y.png');
    });

    test('literal "null" string is treated as missing', () {
      final r = getDoctorImage(
        imageUrl: 'null',
        gender: 'male',
        title: 'Dr.',
      );
      expect(r, contains('male-doc'));
    });

    test('whitespace-only imageUrl is treated as missing', () {
      final r = getDoctorImage(
        imageUrl: '   ',
        gender: 'male',
        title: 'Dr.',
      );
      expect(r, contains('male-doc'));
    });

    test('English Dr. title + male gender → male-doc fallback', () {
      final r = getDoctorImage(
        imageUrl: null,
        gender: 'male',
        title: 'Dr.',
      );
      expect(r, contains('male-doc'));
    });

    test('Arabic د. title + female gender → female-doc fallback', () {
      final r = getDoctorImage(
        imageUrl: null,
        gender: 'أنثى',
        title: 'د.',
      );
      expect(r, contains('female-doc'));
    });

    test('non-doctor + male → male-phys fallback', () {
      final r = getDoctorImage(
        imageUrl: null,
        gender: 'male',
        title: 'Mr.',
      );
      expect(r, contains('male-phys'));
    });

    test('non-doctor + female → female-phys fallback', () {
      final r = getDoctorImage(
        imageUrl: null,
        gender: 'female',
        title: 'Ms.',
      );
      expect(r, contains('female-phys'));
    });

    test('no gender, no title → female-phys (fallback path)', () {
      final r = getDoctorImage(imageUrl: null, gender: null, title: null);
      expect(r, contains('female-phys'));
    });

    test('all variants of doctor title are recognized', () {
      for (final t in ['د.', '.د', 'Dr.', 'د', 'doctor']) {
        final r = getDoctorImage(imageUrl: null, gender: 'male', title: t);
        expect(r, contains('male-doc'),
            reason: 'title=$t should map to doctor');
      }
    });
  });
}
