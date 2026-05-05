import 'package:flutter_test/flutter_test.dart';
import 'package:docsera/models/gift.dart';

Map<String, dynamic> _giftJson({
  String status = 'claimed',
  String? expires,
  String? used,
}) {
  return {
    'claim_id': 'claim-1',
    'promotion_id': 'promo-1',
    'voucher_code': 'GIFT2026',
    'status': status,
    'claimed_at': '2026-05-01T00:00:00Z',
    'expires_at': expires,
    'used_at': used,
    'insight_type': 'birthday',
    'message': 'Happy birthday!',
    'sent_at': '2026-05-01T00:00:00Z',
    'doctor_id': 'doc-1',
    'doctor_name': 'Dr. House',
    'doctor_image': 'https://x/img.png',
    'offer_type': 'voucher',
    'custom_title': 'Birthday gift',
    'custom_title_ar': 'هدية عيد الميلاد',
    'description': 'A treat',
    'description_ar': 'هدية',
    'discount_value': 25.0,
    'discount_type': 'percent',
    'is_unread': true,
  };
}

void main() {
  group('Gift', () {
    test('parses canonical claimed gift', () {
      final g = Gift.fromJson(_giftJson());
      expect(g.claimId, 'claim-1');
      expect(g.voucherCode, 'GIFT2026');
      expect(g.status, 'claimed');
      expect(g.insightType, 'birthday');
      expect(g.doctorName, 'Dr. House');
      expect(g.isUnread, true);
    });

    test('used gift carries usedAt timestamp', () {
      final g = Gift.fromJson(_giftJson(
        status: 'used',
        used: '2026-05-04T10:00:00Z',
      ));
      expect(g.status, 'used');
      expect(g.usedAt, isNotNull);
    });

    test('expired gift carries expiresAt', () {
      final g = Gift.fromJson(_giftJson(expires: '2026-06-01T00:00:00Z'));
      expect(g.expiresAt, isNotNull);
      expect(g.expiresAt!.year, 2026);
    });

    test('discount_value coerces num to double', () {
      final j = _giftJson();
      j['discount_value'] = 30;
      final g = Gift.fromJson(j);
      expect(g.discountValue, 30.0);
    });

    test('claimedAt and sentAt are parsed as DateTimes', () {
      final g = Gift.fromJson(_giftJson());
      expect(g.claimedAt, isA<DateTime>());
      expect(g.sentAt, isA<DateTime>());
    });
  });
}
