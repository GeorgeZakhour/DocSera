import 'package:docsera/models/partner_model.dart';
import 'package:docsera/screens/home/loyalty/widgets/partner_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        locale: const Locale('en'),
        home: ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (_, __) => Scaffold(body: child),
        ),
      );

  testWidgets('PartnerBubble renders partner name', (tester) async {
    final partner = PartnerModel(id: 'p1', name: 'Al-Razi Pharmacy');
    await tester.pumpWidget(wrap(PartnerBubble(partner: partner, onTap: () {})));
    await tester.pump();

    expect(find.text('Al-Razi Pharmacy'), findsOneWidget);
  });

  testWidgets('PartnerBubble shows initials fallback when logo url is null', (tester) async {
    final partner = PartnerModel(id: 'p1', name: 'Optical House');
    await tester.pumpWidget(wrap(PartnerBubble(partner: partner, onTap: () {})));
    await tester.pump();

    expect(find.text('O'), findsOneWidget);
  });

  testWidgets('PartnerBubble triggers onTap', (tester) async {
    var tapped = false;
    final partner = PartnerModel(id: 'p1', name: 'Al-Razi');
    await tester.pumpWidget(
      wrap(PartnerBubble(partner: partner, onTap: () => tapped = true)),
    );
    await tester.pump();
    await tester.tap(find.byType(PartnerBubble));
    expect(tapped, isTrue);
  });
}
