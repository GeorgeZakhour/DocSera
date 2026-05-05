import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:docsera/Business_Logic/Loyalty/vouchers/vouchers_cubit.dart';
import 'package:docsera/Business_Logic/Loyalty/vouchers/vouchers_state.dart';
import 'package:docsera/models/voucher_model.dart';
import 'package:docsera/services/supabase/loyalty/loyalty_service.dart';

class _MockLoyalty extends Mock implements LoyaltyService {}

VoucherModel _voucher({
  String id = 'v1',
  String status = 'active',
  String expires = '2099-12-31T00:00:00Z',
}) {
  return VoucherModel(
    id: id,
    offerId: 'o1',
    code: 'CODE',
    status: status,
    redeemedAt: '2026-05-01T00:00:00Z',
    expiresAt: expires,
  );
}

void main() {
  late VouchersCubit cubit;
  late _MockLoyalty service;

  setUp(() {
    service = _MockLoyalty();
    cubit = VouchersCubit(service);
  });

  tearDown(() => cubit.close());

  group('VouchersCubit.loadVouchers', () {
    blocTest<VouchersCubit, VouchersState>(
      'partitions vouchers into active / used / expired buckets',
      build: () {
        when(() => service.getUserVouchers()).thenAnswer((_) async => [
              _voucher(id: 'a1', status: 'active'),
              _voucher(id: 'u1', status: 'used'),
              _voucher(
                id: 'e1',
                status: 'active',
                expires: '2020-01-01T00:00:00Z',
              ),
            ]);
        when(() => service.getMyDoctorPromotionClaims())
            .thenAnswer((_) async => const []);
        when(() => service.getMyGifts()).thenAnswer((_) async => const []);
        return cubit;
      },
      act: (c) => c.loadVouchers(),
      expect: () => [
        isA<VouchersLoading>(),
        isA<VouchersLoaded>()
            .having((s) => s.active.length, 'active', 1)
            .having((s) => s.used.length, 'used', 1)
            .having((s) => s.expired.length, 'expired', 1),
      ],
    );

    blocTest<VouchersCubit, VouchersState>(
      'gifts fetch failure does not break voucher rendering',
      build: () {
        when(() => service.getUserVouchers())
            .thenAnswer((_) async => [_voucher()]);
        when(() => service.getMyDoctorPromotionClaims())
            .thenAnswer((_) async => const []);
        when(() => service.getMyGifts()).thenThrow(Exception('rls denied'));
        return cubit;
      },
      act: (c) => c.loadVouchers(),
      expect: () => [
        isA<VouchersLoading>(),
        isA<VouchersLoaded>().having((s) => s.gifts, 'gifts', isEmpty),
      ],
    );

    blocTest<VouchersCubit, VouchersState>(
      'vouchers fetch failure → VouchersError (everything fails)',
      build: () {
        when(() => service.getUserVouchers())
            .thenThrow(Exception('db down'));
        when(() => service.getMyDoctorPromotionClaims())
            .thenAnswer((_) async => const []);
        return cubit;
      },
      act: (c) => c.loadVouchers(),
      expect: () => [
        isA<VouchersLoading>(),
        isA<VouchersError>(),
      ],
    );

    blocTest<VouchersCubit, VouchersState>(
      'merges partner-voucher list and doctor-promotion-claim list',
      build: () {
        when(() => service.getUserVouchers())
            .thenAnswer((_) async => [_voucher(id: 'partner-1')]);
        when(() => service.getMyDoctorPromotionClaims())
            .thenAnswer((_) async => [_voucher(id: 'doctor-1')]);
        when(() => service.getMyGifts()).thenAnswer((_) async => const []);
        return cubit;
      },
      act: (c) => c.loadVouchers(),
      verify: (c) {
        final loaded = c.state as VouchersLoaded;
        final ids = loaded.active.map((v) => v.id).toSet();
        expect(ids, containsAll(['partner-1', 'doctor-1']));
      },
    );
  });
}
