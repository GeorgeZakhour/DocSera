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

  testWidgets('renders title, points pill and start CTA', (tester) async {
    await tester.pumpWidget(wrap(CompleteProfileBanner(
      progress: 0.0,
      onTap: () {},
    )));
    // Heart icon (in the bubble) + arrow icon (on the start chip)
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    // The +15 sits in the points pill
    expect(find.text('15'), findsOneWidget);
    // The CTA label
    expect(find.text('Start'), findsOneWidget);
  });

  testWidgets('invokes onTap when CTA pressed', (tester) async {
    var taps = 0;
    await tester.pumpWidget(wrap(CompleteProfileBanner(
      progress: 0.0,
      onTap: () => taps++,
    )));
    await tester.tap(find.text('Start'));
    await tester.pump(); // one frame — pulse animation loops forever
    expect(taps, 1);
  });

  testWidgets('shows arrow icon next to Start label', (tester) async {
    await tester.pumpWidget(wrap(CompleteProfileBanner(
      progress: 0.0,
      onTap: () {},
    )));
    // RTL is the default in this app's tests; in any direction one of
    // these arrows should be present alongside the Start label.
    final hasArrow =
        find.byIcon(Icons.arrow_forward_rounded).evaluate().isNotEmpty ||
            find.byIcon(Icons.arrow_back_rounded).evaluate().isNotEmpty;
    expect(hasArrow, isTrue);
  });
}
