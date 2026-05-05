import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:docsera/Business_Logic/Banners/banners_cubit.dart';
import 'package:docsera/Business_Logic/Banners/banners_state.dart';
import 'package:docsera/models/banner_model.dart';
import 'package:docsera/services/supabase/banners/supabase_banner_service.dart';

class _MockBannerService extends Mock implements SupabaseBannerService {}

BannerModel _banner({String id = 'b1', bool active = true, int order = 0}) {
  return BannerModel(
    id: id,
    imagePath: 'https://x/img.png',
    isActive: active,
    orderIndex: order,
  );
}

void main() {
  late BannersCubit cubit;
  late _MockBannerService service;

  setUp(() {
    service = _MockBannerService();
    cubit = BannersCubit(service);
  });

  tearDown(() => cubit.close());

  group('BannersCubit', () {
    test('initial state is BannersInitial', () {
      expect(cubit.state, isA<BannersInitial>());
    });

    blocTest<BannersCubit, BannersState>(
      'loadBanners success → [Loading, Loaded]',
      build: () {
        when(() => service.getActiveBanners())
            .thenAnswer((_) async => [_banner(id: 'b1'), _banner(id: 'b2')]);
        return cubit;
      },
      act: (c) => c.loadBanners(),
      expect: () => [
        isA<BannersLoading>(),
        isA<BannersLoaded>().having((s) => s.banners.length, 'count', 2),
      ],
    );

    blocTest<BannersCubit, BannersState>(
      'loadBanners empty → [Loading, Loaded(empty)]',
      build: () {
        when(() => service.getActiveBanners())
            .thenAnswer((_) async => const []);
        return cubit;
      },
      act: (c) => c.loadBanners(),
      expect: () => [
        isA<BannersLoading>(),
        isA<BannersLoaded>().having((s) => s.banners, 'banners', isEmpty),
      ],
    );

    blocTest<BannersCubit, BannersState>(
      'loadBanners service throws → [Loading, Error]',
      build: () {
        when(() => service.getActiveBanners()).thenThrow(Exception('db down'));
        return cubit;
      },
      act: (c) => c.loadBanners(),
      expect: () => [
        isA<BannersLoading>(),
        isA<BannersError>(),
      ],
    );

    blocTest<BannersCubit, BannersState>(
      'second loadBanners refetches (no caching in cubit)',
      build: () {
        when(() => service.getActiveBanners())
            .thenAnswer((_) async => [_banner()]);
        return cubit;
      },
      act: (c) async {
        await c.loadBanners();
        await c.loadBanners();
      },
      verify: (_) {
        verify(() => service.getActiveBanners()).called(2);
      },
    );
  });
}
