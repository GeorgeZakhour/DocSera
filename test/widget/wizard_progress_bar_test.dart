import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/screens/home/health/wizard/widgets/wizard_progress_bar.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        home: ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (_, __) => Scaffold(body: child),
        ),
      );

  testWidgets('renders the requested number of segments', (tester) async {
    await tester.pumpWidget(wrap(
      const WizardProgressBar(totalSteps: 10, currentIndex: 3),
    ));
    expect(find.byType(AnimatedContainer), findsNWidgets(10));
  });

  testWidgets('filled segments use a gradient when index < currentIndex',
      (tester) async {
    await tester.pumpWidget(wrap(
      const WizardProgressBar(totalSteps: 5, currentIndex: 2),
    ));
    // Find all AnimatedContainers in document order; segments 0 and 1 should
    // have a gradient set, segments 2..4 should not.
    final containers =
        tester.widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
            .toList();
    final filledGradients = containers
        .where((c) => (c.decoration as BoxDecoration).gradient != null)
        .length;
    expect(filledGradients, 2);
  });

  testWidgets('renders correctly at currentIndex 0 (no filled segments)',
      (tester) async {
    await tester.pumpWidget(wrap(
      const WizardProgressBar(totalSteps: 10, currentIndex: 0),
    ));
    final containers =
        tester.widgetList<AnimatedContainer>(find.byType(AnimatedContainer));
    final filled = containers
        .where((c) => (c.decoration as BoxDecoration).gradient != null)
        .length;
    expect(filled, 0);
  });
}
