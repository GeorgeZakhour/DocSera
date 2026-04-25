import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/screens/home/health/widgets/complete_profile_banner.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (_, __) => Scaffold(body: child),
        ),
      );

  testWidgets('renders progress ring + start CTA', (tester) async {
    await tester.pumpWidget(wrap(CompleteProfileBanner(
      progress: 0.3,
      onTap: () {},
    )));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
  });

  testWidgets('invokes onTap when CTA pressed', (tester) async {
    var taps = 0;
    await tester.pumpWidget(wrap(CompleteProfileBanner(
      progress: 0.0,
      onTap: () => taps++,
    )));
    await tester.tap(find.text('Start'));
    await tester.pump(); // one frame — no pumpAndSettle because the pulse animation loops forever
    expect(taps, 1);
  });
}
