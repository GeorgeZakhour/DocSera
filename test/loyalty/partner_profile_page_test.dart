import 'package:docsera/Business_Logic/Loyalty/partner/partner_cubit.dart';
import 'package:docsera/Business_Logic/Loyalty/partner/partner_state.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/models/offer_model.dart';
import 'package:docsera/models/partner_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';

class MockPartnerCubit extends MockCubit<PartnerState> implements PartnerCubit {}

Widget _wrap(Widget child) => MaterialApp(
      locale: const Locale('en'),
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, __) => child,
      ),
    );

void main() {
  testWidgets('Loaded state cubit can be constructed without crashing', (tester) async {
    final cubit = MockPartnerCubit();
    when(() => cubit.state).thenReturn(
      PartnerLoaded(
        partner: PartnerModel(id: 'p1', name: 'Al-Razi', address: 'Damascus'),
        offers: [
          OfferModel(id: 'o1', category: 'partner', title: 'Vitamins 10%', pointsCost: 200),
        ],
      ),
    );

    await tester.pumpWidget(_wrap(
      Scaffold(
        body: BlocProvider<PartnerCubit>.value(
          value: cubit,
          child: const SizedBox(),
        ),
      ),
    ));

    // Compile-time scaffold test — verifies imports + cubit/state construction.
    expect(tester.takeException(), isNull);
  });
}
