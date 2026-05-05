import 'package:flutter_test/flutter_test.dart';
import 'package:docsera/models/promotion.dart';

Map<String, dynamic> _doctorPromo() => {
      'id': 'p1',
      'doctor_id': 'd1',
      'owner_type': 'doctor',
      'offer_type': 'discount',
      'audience': 'all_patients',
      'custom_title': 'Spring Sale',
      'custom_title_ar': 'تخفيضات الربيع',
      'description': 'desc',
      'discount_value': 25.0,
      'discount_type': 'percent',
      'is_featured': true,
      'is_archived': false,
    };

Map<String, dynamic> _centerPromo({List<String>? targets}) => {
      'id': 'p2',
      'center_id': 'c1',
      'center_name': 'Center One',
      'owner_type': 'center',
      'offer_type': 'voucher',
      'audience': 'returning_patients',
      'target_doctor_ids': targets,
      'points_cost': 50,
      'end_date': '2026-12-31T00:00:00Z',
    };

void main() {
  group('Promotion — doctor-owned', () {
    test('parses canonical doctor promo', () {
      final p = Promotion.fromJson(_doctorPromo());
      expect(p.id, 'p1');
      expect(p.doctorId, 'd1');
      expect(p.centerId, isNull);
      expect(p.ownerType, 'doctor');
      expect(p.targetScope, 'doctor');
      expect(p.isFeatured, true);
      expect(p.isArchived, false);
    });

    test('discount_value coerces int → double', () {
      final j = _doctorPromo();
      j['discount_value'] = 25;
      expect(Promotion.fromJson(j).discountValue, 25.0);
    });

    test('owner_type missing → inferred from doctor_id', () {
      final j = _doctorPromo();
      j.remove('owner_type');
      expect(Promotion.fromJson(j).ownerType, 'doctor');
    });

    test('audience defaults to all_patients when missing', () {
      final j = _doctorPromo();
      j.remove('audience');
      expect(Promotion.fromJson(j).audience, 'all_patients');
    });
  });

  group('Promotion — center-owned', () {
    test('parses center-wide promo (empty target list)', () {
      final p = Promotion.fromJson(_centerPromo(targets: const []));
      expect(p.centerId, 'c1');
      expect(p.targetScope, 'center_wide');
      expect(p.targetDoctorIds, isEmpty);
    });

    test('targetScope is "center_selected" when targets are non-empty', () {
      final p = Promotion.fromJson(_centerPromo(targets: ['d1', 'd2']));
      expect(p.targetScope, 'center_selected');
      expect(p.targetDoctorIds, ['d1', 'd2']);
    });

    test('null target_doctor_ids defaults to empty list', () {
      final p = Promotion.fromJson(_centerPromo(targets: null));
      expect(p.targetDoctorIds, isEmpty);
    });

    test('end_date parses to DateTime', () {
      final p = Promotion.fromJson(_centerPromo(targets: const []));
      expect(p.endDate, isA<DateTime>());
      expect(p.endDate!.year, 2026);
    });
  });
}
