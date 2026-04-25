import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/screens/home/health/wizard/widgets/wizard_no_data_button.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        home: ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (_, __) => Scaffold(body: child),
        ),
      );

  testWidgets('shown when nothing selected', (tester) async {
    await tester.pumpWidget(wrap(WizardNoDataButton(
      label: 'No allergy',
      anySelected: false,
      onTap: () {},
    )));
    expect(find.text('No allergy'), findsOneWidget);
  });

  testWidgets('hidden when something is selected', (tester) async {
    await tester.pumpWidget(wrap(WizardNoDataButton(
      label: 'No allergy',
      anySelected: true,
      onTap: () {},
    )));
    await tester.pumpAndSettle();
    expect(find.text('No allergy'), findsNothing);
  });

  testWidgets('invokes onTap when pressed', (tester) async {
    var taps = 0;
    await tester.pumpWidget(wrap(WizardNoDataButton(
      label: 'No condition',
      anySelected: false,
      onTap: () => taps++,
    )));
    await tester.tap(find.text('No condition'));
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  testWidgets('animates between visible and hidden', (tester) async {
    bool selected = false;
    await tester.pumpWidget(StatefulBuilder(
      builder: (context, setState) => wrap(WizardNoDataButton(
        label: 'No surgery',
        anySelected: selected,
        onTap: () => setState(() => selected = true),
      )),
    ));

    expect(find.text('No surgery'), findsOneWidget);
    await tester.tap(find.text('No surgery'));
    await tester.pump(); // start animation
    await tester.pump(const Duration(milliseconds: 100)); // mid-animation
    await tester.pumpAndSettle(); // finish
    expect(find.text('No surgery'), findsNothing);
  });
}
