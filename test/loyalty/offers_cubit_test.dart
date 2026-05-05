import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:docsera/Business_Logic/Loyalty/offers/offers_cubit.dart';
import 'package:docsera/Business_Logic/Loyalty/offers/offers_state.dart';
import 'package:docsera/models/offer_model.dart';
import 'package:docsera/services/supabase/loyalty/loyalty_service.dart';

class _MockLoyalty extends Mock implements LoyaltyService {}

OfferModel _offer({String id = 'o1', int points = 100}) {
  return OfferModel(
    id: id,
    category: 'beauty',
    title: 'Spa',
    pointsCost: points,
  );
}

void main() {
  late OffersCubit cubit;
  late _MockLoyalty service;

  setUp(() {
    service = _MockLoyalty();
    cubit = OffersCubit(service);
  });

  tearDown(() => cubit.close());

  group('OffersCubit.loadOffers', () {
    blocTest<OffersCubit, OffersState>(
      'success → [Loading, Loaded] with all offers',
      build: () {
        when(() => service.getAvailableOffers(
                category: any(named: 'category')))
            .thenAnswer((_) async => [_offer(id: 'o1'), _offer(id: 'o2')]);
        return cubit;
      },
      act: (c) => c.loadOffers(),
      expect: () => [
        isA<OffersLoading>(),
        isA<OffersLoaded>().having((s) => s.allOffers.length, 'count', 2),
      ],
    );

    blocTest<OffersCubit, OffersState>(
      'success with category filter passes through',
      build: () {
        when(() => service.getAvailableOffers(category: 'food'))
            .thenAnswer((_) async => [_offer(id: 'food-1')]);
        return cubit;
      },
      act: (c) => c.loadOffers(category: 'food'),
      verify: (_) {
        verify(() => service.getAvailableOffers(category: 'food')).called(1);
      },
    );

    blocTest<OffersCubit, OffersState>(
      'service throws → [Loading, Error]',
      build: () {
        when(() => service.getAvailableOffers(
                category: any(named: 'category')))
            .thenThrow(Exception('db down'));
        return cubit;
      },
      act: (c) => c.loadOffers(),
      expect: () => [
        isA<OffersLoading>(),
        isA<OffersError>(),
      ],
    );

    blocTest<OffersCubit, OffersState>(
      'empty list emits Loaded with empty allOffers',
      build: () {
        when(() => service.getAvailableOffers(
                category: any(named: 'category')))
            .thenAnswer((_) async => const []);
        return cubit;
      },
      act: (c) => c.loadOffers(),
      expect: () => [
        isA<OffersLoading>(),
        isA<OffersLoaded>().having((s) => s.allOffers, 'allOffers', isEmpty),
      ],
    );
  });

  group('OffersCubit.redeemOffer', () {
    blocTest<OffersCubit, OffersState>(
      'success → [RedeemLoading, RedeemSuccess] with voucher code',
      build: () {
        when(() => service.redeemOffer('o1'))
            .thenAnswer((_) async => {
                  'success': true,
                  'voucher_code': 'CODE123',
                  'expires_at': '2026-12-31',
                });
        return cubit;
      },
      act: (c) => c.redeemOffer('o1'),
      expect: () => [
        isA<OfferRedeemLoading>(),
        isA<OfferRedeemSuccess>()
            .having((s) => s.voucherCode, 'voucherCode', 'CODE123')
            .having((s) => s.expiresAt, 'expiresAt', '2026-12-31'),
      ],
    );

    blocTest<OffersCubit, OffersState>(
      'failure with explicit error code → RedeemError',
      build: () {
        when(() => service.redeemOffer(any()))
            .thenAnswer((_) async => {
                  'success': false,
                  'error': 'insufficient_points',
                });
        return cubit;
      },
      act: (c) => c.redeemOffer('o1'),
      expect: () => [
        isA<OfferRedeemLoading>(),
        isA<OfferRedeemError>()
            .having((s) => s.error, 'error', 'insufficient_points'),
      ],
    );

    blocTest<OffersCubit, OffersState>(
      'failure with no error key → RedeemError(unknown_error)',
      build: () {
        when(() => service.redeemOffer(any()))
            .thenAnswer((_) async => {'success': false});
        return cubit;
      },
      act: (c) => c.redeemOffer('o1'),
      expect: () => [
        isA<OfferRedeemLoading>(),
        isA<OfferRedeemError>()
            .having((s) => s.error, 'error', 'unknown_error'),
      ],
    );
  });
}
