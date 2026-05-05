import 'package:flutter_test/flutter_test.dart';
import 'package:docsera/models/referral_model.dart';

void main() {
  group('ReferralModel', () {
    test('parses canonical referral with completed_at', () {
      final r = ReferralModel.fromJson({
        'id': 'r1',
        'referred_name': 'Friend',
        'completed_at': '2026-05-01T00:00:00Z',
        'points_awarded': 50,
      });
      expect(r.id, 'r1');
      expect(r.referredName, 'Friend');
      expect(r.completedAt, isNotNull);
      expect(r.pointsAwarded, 50);
    });

    test('points_awarded defaults to 25 when missing', () {
      final r = ReferralModel.fromJson({'id': 'r2'});
      expect(r.pointsAwarded, 25);
    });

    test('null referred_name and completed_at stay null', () {
      final r = ReferralModel.fromJson({'id': 'r3'});
      expect(r.referredName, isNull);
      expect(r.completedAt, isNull);
    });
  });

  group('ReferralInfo', () {
    test('parses canonical info with recent referrals', () {
      final info = ReferralInfo.fromJson({
        'referral_code': 'ABC123',
        'total_referrals': 5,
        'total_points_earned': 125,
        'recent_referrals': [
          {'id': 'r1', 'points_awarded': 25},
          {'id': 'r2', 'points_awarded': 50},
        ],
      });
      expect(info.referralCode, 'ABC123');
      expect(info.totalReferrals, 5);
      expect(info.totalPointsEarned, 125);
      expect(info.recentReferrals, hasLength(2));
    });

    test('missing recent_referrals → empty list', () {
      final info = ReferralInfo.fromJson({'referral_code': 'X'});
      expect(info.recentReferrals, isEmpty);
    });

    test('missing totals default to 0', () {
      final info = ReferralInfo.fromJson({'referral_code': 'X'});
      expect(info.totalReferrals, 0);
      expect(info.totalPointsEarned, 0);
    });
  });
}
