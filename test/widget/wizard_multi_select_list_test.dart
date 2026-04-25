import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/screens/home/health/wizard/widgets/wizard_multi_select_list.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (_, __) => Scaffold(body: child),
        ),
      );

  testWidgets('toggles checkbox via row tap', (tester) async {
    String? lastId;
    bool? lastChecked;
    await tester.pumpWidget(wrap(WizardMultiSelectList(
      items: const [
        MultiSelectItem(id: 'a', label: 'Pollen', isExisting: false),
      ],
      selectedIds: const {},
      onToggle: (item, c) {
        lastId = item.id;
        lastChecked = c;
      },
      onAddManual: () {},
      addManualLabel: '+ Add an allergy',
    )));
    await tester.tap(find.text('Pollen'));
    await tester.pumpAndSettle();
    expect(lastId, 'a');
    expect(lastChecked, true);
  });

  testWidgets('renders "Already in your profile" tag for existing items',
      (tester) async {
    await tester.pumpWidget(wrap(WizardMultiSelectList(
      items: const [
        MultiSelectItem(id: 'a', label: 'Pollen', isExisting: true),
        MultiSelectItem(id: 'b', label: 'Latex', isExisting: false),
      ],
      selectedIds: const {'a'},
      onToggle: (_, __) {},
      onAddManual: () {},
      addManualLabel: '+ Add an allergy',
    )));
    expect(find.text('Already in your profile'), findsOneWidget);
  });

  testWidgets('add-manual row invokes callback', (tester) async {
    var taps = 0;
    await tester.pumpWidget(wrap(WizardMultiSelectList(
      items: const [],
      selectedIds: const {},
      onToggle: (_, __) {},
      onAddManual: () => taps++,
      addManualLabel: '+ Add an allergy',
    )));
    await tester.tap(find.text('+ Add an allergy'));
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  testWidgets('toggling an already-selected item emits checked=false',
      (tester) async {
    bool? lastChecked;
    await tester.pumpWidget(wrap(WizardMultiSelectList(
      items: const [
        MultiSelectItem(id: 'a', label: 'Pollen', isExisting: false),
      ],
      selectedIds: const {'a'},
      onToggle: (_, c) => lastChecked = c,
      onAddManual: () {},
      addManualLabel: '+ Add an allergy',
    )));
    await tester.tap(find.text('Pollen'));
    await tester.pumpAndSettle();
    expect(lastChecked, false);
  });
}
