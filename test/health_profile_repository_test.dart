import 'package:docsera/services/supabase/repositories/health_profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CompleteHealthProfileResult.fromMap', () {
    test('parses a fully-populated map correctly', () {
      final map = {
        'already_awarded': true,
        'new_balance': 50,
        'completed_at': '2026-04-25T10:00:00.000Z',
      };

      final result = CompleteHealthProfileResult.fromMap(map);

      expect(result.alreadyAwarded, isTrue);
      expect(result.newBalance, 50);
      expect(result.completedAt,
          DateTime.parse('2026-04-25T10:00:00.000Z'));
    });

    test('throws FormatException when completed_at is null', () {
      expect(
        () => CompleteHealthProfileResult.fromMap({
          'already_awarded': null,
          'new_balance': null,
          'completed_at': null,
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException when completed_at is missing', () {
      expect(
        () => CompleteHealthProfileResult.fromMap({}),
        throwsA(isA<FormatException>()),
      );
    });

    test('uses defaults for missing already_awarded and new_balance when completed_at present', () {
      final result = CompleteHealthProfileResult.fromMap({
        'completed_at': '2026-04-25T00:00:00.000Z',
      });
      expect(result.alreadyAwarded, isFalse);
      expect(result.newBalance, 0);
    });

    test('coerces num new_balance to int', () {
      final result = CompleteHealthProfileResult.fromMap({
        'already_awarded': false,
        'new_balance': 35.0, // num, not int
        'completed_at': '2026-04-25T00:00:00.000Z',
      });

      expect(result.newBalance, 35);
      expect(result.newBalance, isA<int>());
    });
  });

  group('HealthProfileRepository.buildUpsertParams', () {
    test('includes only non-null fields', () {
      final params = HealthProfileRepository.buildUpsertParams(
        heightCm: 175,
        weightKg: null,
        sportFrequency: 'weekly',
        smokingStatus: null,
        alcoholFrequency: null,
      );

      expect(params, containsPair('p_height_cm', 175));
      expect(params, containsPair('p_sport_frequency', 'weekly'));
      expect(params, isNot(contains('p_weight_kg')));
      expect(params, isNot(contains('p_smoking_status')));
      expect(params, isNot(contains('p_alcohol_frequency')));
    });

    test('returns empty map when all args are null', () {
      final params = HealthProfileRepository.buildUpsertParams();
      expect(params, isEmpty);
    });

    test('includes all fields when all args are provided', () {
      final params = HealthProfileRepository.buildUpsertParams(
        heightCm: 170,
        weightKg: 70,
        sportFrequency: 'daily',
        smokingStatus: 'never',
        alcoholFrequency: 'never',
      );

      expect(params.length, 5);
      expect(params['p_height_cm'], 170);
      expect(params['p_weight_kg'], 70);
      expect(params['p_sport_frequency'], 'daily');
      expect(params['p_smoking_status'], 'never');
      expect(params['p_alcohol_frequency'], 'never');
    });
  });
}
