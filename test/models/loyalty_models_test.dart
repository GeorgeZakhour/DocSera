// Round-trip tests for the loyalty model family: OfferModel, VoucherModel,
// PartnerModel. These flow through the redemption funnel; schema drift
// would break the entire loyalty feature silently.

import 'package:flutter_test/flutter_test.dart';
import 'package:docsera/models/offer_model.dart';
import 'package:docsera/models/voucher_model.dart';
import 'package:docsera/models/partner_model.dart';

Map<String, dynamic> _offerJson({
  String id = 'offer-1',
  String category = 'beauty',
  String title = 'Spa Day',
  int pointsCost = 100,
  bool isMega = false,
  int currentRedemptions = 0,
  int? max,
}) {
  return {
    'id': id,
    'category': category,
    'title': title,
    'title_ar': 'يوم سبا',
    'description': 'enjoy',
    'description_ar': 'استمتع',
    'points_cost': pointsCost,
    'partner_id': 'p1',
    'partner_name': 'Partner',
    'partner_name_ar': 'شريك',
    'partner_logo_url': 'https://x/p.png',
    'partner_address': 'Street',
    'partner_address_ar': 'شارع',
    'partner_brand_color': '#ff0000',
    'partner_type': 'spa',
    'partner_cover_url': 'https://x/c.png',
    'partner_offer_count': 3,
    'discount_type': 'percent',
    'discount_value': 25.0,
    'max_redemptions': max,
    'current_redemptions': currentRedemptions,
    'start_date': '2026-01-01',
    'end_date': '2026-12-31',
    'is_mega_offer': isMega,
    'voucher_validity_days': 14,
    'image_url': 'https://x/img.png',
  };
}

void main() {
  group('OfferModel', () {
    test('canonical fromJson populates all fields', () {
      final o = OfferModel.fromJson(_offerJson());
      expect(o.id, 'offer-1');
      expect(o.category, 'beauty');
      expect(o.title, 'Spa Day');
      expect(o.titleAr, 'يوم سبا');
      expect(o.pointsCost, 100);
      expect(o.partnerName, 'Partner');
      expect(o.discountValue, 25.0);
      expect(o.voucherValidityDays, 14);
      expect(o.isMegaOffer, false);
    });

    test('isMegaOffer flag round-trips', () {
      final o = OfferModel.fromJson(_offerJson(isMega: true));
      expect(o.isMegaOffer, true);
    });

    test('partnerOfferCount defaults to 0 when null', () {
      final j = _offerJson();
      j.remove('partner_offer_count');
      final o = OfferModel.fromJson(j);
      expect(o.partnerOfferCount, 0);
    });

    test('currentRedemptions defaults to 0 when null', () {
      final j = _offerJson();
      j.remove('current_redemptions');
      final o = OfferModel.fromJson(j);
      expect(o.currentRedemptions, 0);
    });

    test('discount_value coerces num to double', () {
      final j = _offerJson();
      j['discount_value'] = 30; // int, not double
      final o = OfferModel.fromJson(j);
      expect(o.discountValue, 30.0);
    });

    test('max_redemptions=null leaves nullable field null', () {
      final o = OfferModel.fromJson(_offerJson(max: null));
      expect(o.maxRedemptions, isNull);
    });
  });

  group('VoucherModel', () {
    Map<String, dynamic> voucherJson({String status = 'active', String? usedAt}) =>
        {
          'id': 'v1',
          'offer_id': 'offer-1',
          'code': 'CODE123',
          'status': status,
          'redeemed_at': '2026-05-01T00:00:00Z',
          'used_at': usedAt,
          'expires_at': '2026-05-15T00:00:00Z',
          'offer_title': 'Spa',
          'offer_title_ar': 'سبا',
          'offer_description': 'desc',
          'offer_description_ar': 'وصف',
          'offer_category': 'beauty',
          'discount_type': 'percent',
          'discount_value': 25.0,
          'partner_name': 'Partner',
          'partner_name_ar': 'شريك',
          'partner_address': 'Street',
          'partner_address_ar': 'شارع',
          'partner_logo_url': 'https://x/p.png',
        };

    test('parses canonical active voucher', () {
      final v = VoucherModel.fromJson(voucherJson());
      expect(v.id, 'v1');
      expect(v.status, 'active');
      expect(v.usedAt, isNull);
      expect(v.code, 'CODE123');
    });

    test('used voucher has usedAt populated', () {
      final v = VoucherModel.fromJson(
        voucherJson(status: 'used', usedAt: '2026-05-05T10:00:00Z'),
      );
      expect(v.status, 'used');
      expect(v.usedAt, isNotNull);
    });

    test('discount_value coerces num to double', () {
      final j = voucherJson();
      j['discount_value'] = 50;
      final v = VoucherModel.fromJson(j);
      expect(v.discountValue, 50.0);
    });
  });

  group('PartnerModel', () {
    Map<String, dynamic> partnerJson({bool active = true}) => {
          'id': 'p1',
          'name': 'Partner',
          'name_ar': 'شريك',
          'logo_url': 'https://x/p.png',
          'cover_url': 'https://x/c.png',
          'brand_color': '#ff0000',
          'partner_type': 'spa',
          'address': 'Street',
          'address_ar': 'شارع',
          'phone': '+963 11 1234567',
          'about': 'about',
          'about_ar': 'عن',
          'is_active': active,
        };

    test('parses canonical active partner', () {
      final p = PartnerModel.fromJson(partnerJson());
      expect(p.id, 'p1');
      expect(p.name, 'Partner');
      expect(p.isActive, true);
    });

    test('inactive partner round-trips', () {
      final p = PartnerModel.fromJson(partnerJson(active: false));
      expect(p.isActive, false);
    });

    test('isActive defaults to true when missing', () {
      final j = partnerJson();
      j.remove('is_active');
      final p = PartnerModel.fromJson(j);
      expect(p.isActive, true);
    });
  });
}
