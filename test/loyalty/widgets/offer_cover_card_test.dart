import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/models/offer_model.dart';
import 'package:docsera/screens/home/loyalty/widgets/offer_cover_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
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
          builder: (_, __) => Scaffold(body: child),
        ),
      );

  OfferModel build({
    bool isMega = false,
    int? maxRedemptions,
    int currentRedemptions = 0,
    String? imageUrl,
  }) =>
      OfferModel(
        id: 'o1',
        category: 'partner',
        title: '10% off vitamins',
        partnerName: 'Al-Razi',
        pointsCost: 200,
        isMegaOffer: isMega,
        maxRedemptions: maxRedemptions,
        currentRedemptions: currentRedemptions,
        imageUrl: imageUrl,
      );

  testWidgets('renders title and partner name', (tester) async {
    await tester.pumpWidget(
      wrap(OfferCoverCard(offer: build(), onTap: () {})),
    );
    await tester.pump();
    expect(find.text('10% off vitamins'), findsOneWidget);
    expect(find.text('Al-Razi'), findsOneWidget);
  });

  testWidgets('shows MEGA ribbon when isMegaOffer', (tester) async {
    await tester.pumpWidget(
      wrap(OfferCoverCard(offer: build(isMega: true), onTap: () {})),
    );
    await tester.pump();
    expect(find.textContaining('MEGA'), findsOneWidget);
  });

  testWidgets('does not show "X left" when remaining >= 20', (tester) async {
    await tester.pumpWidget(
      wrap(OfferCoverCard(
        offer: build(maxRedemptions: 100, currentRedemptions: 50),
        onTap: () {},
      )),
    );
    await tester.pump();
    expect(find.textContaining('left'), findsNothing);
  });

  testWidgets('shows "X left" when remaining < 20', (tester) async {
    await tester.pumpWidget(
      wrap(OfferCoverCard(
        offer: build(maxRedemptions: 100, currentRedemptions: 95),
        onTap: () {},
      )),
    );
    await tester.pump();
    expect(find.textContaining('5'), findsWidgets);
  });

  testWidgets('triggers onTap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      wrap(OfferCoverCard(offer: build(), onTap: () => tapped = true)),
    );
    await tester.pump();
    await tester.tap(find.byType(OfferCoverCard));
    expect(tapped, isTrue);
  });
}
