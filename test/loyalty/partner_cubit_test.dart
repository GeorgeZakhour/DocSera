import 'package:bloc_test/bloc_test.dart';
import 'package:docsera/Business_Logic/Loyalty/partner/partner_cubit.dart';
import 'package:docsera/Business_Logic/Loyalty/partner/partner_state.dart';
import 'package:docsera/models/offer_model.dart';
import 'package:docsera/models/partner_model.dart';
import 'package:docsera/services/supabase/loyalty/loyalty_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockLoyaltyService extends Mock implements LoyaltyService {}

void main() {
  late PartnerCubit cubit;
  late MockLoyaltyService service;

  setUp(() {
    service = MockLoyaltyService();
    cubit = PartnerCubit(service);
  });

  tearDown(() => cubit.close());

  final partner = PartnerModel(id: 'p1', name: 'Al-Razi');
  final offers = [
    OfferModel(id: 'o1', category: 'partner', title: 'Vitamins', pointsCost: 100, partnerId: 'p1'),
  ];

  group('PartnerCubit', () {
    test('initial state is PartnerInitial', () {
      expect(cubit.state, isA<PartnerInitial>());
    });

    blocTest<PartnerCubit, PartnerState>(
      'emits [Loading, Loaded] on success',
      build: () {
        when(() => service.getPartnerProfile('p1'))
            .thenAnswer((_) async => (partner: partner, offers: offers));
        return cubit;
      },
      act: (c) => c.load('p1'),
      expect: () => [
        isA<PartnerLoading>(),
        predicate<PartnerState>(
            (s) => s is PartnerLoaded && s.partner.id == 'p1' && s.offers.length == 1),
      ],
    );

    blocTest<PartnerCubit, PartnerState>(
      'emits [Loading, NotFound] when service returns null',
      build: () {
        when(() => service.getPartnerProfile('missing'))
            .thenAnswer((_) async => null);
        return cubit;
      },
      act: (c) => c.load('missing'),
      expect: () => [
        isA<PartnerLoading>(),
        isA<PartnerNotFound>(),
      ],
    );

    blocTest<PartnerCubit, PartnerState>(
      'emits [Loading, Error] when service throws',
      build: () {
        when(() => service.getPartnerProfile(any()))
            .thenThrow(Exception('boom'));
        return cubit;
      },
      act: (c) => c.load('p1'),
      expect: () => [
        isA<PartnerLoading>(),
        isA<PartnerError>(),
      ],
    );
  });
}
