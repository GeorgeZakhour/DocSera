// Widget-test harness. Wraps the widget under test with the minimum
// shell needed for it to render: MaterialApp + project l10n delegates +
// ScreenUtil + an optional MultiBlocProvider for mocked Cubits.
//
// Tests should `await tester.pumpAppWidget(myWidget)` instead of
// re-implementing 30 lines of setup each.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:docsera/gen_l10n/app_localizations.dart';

extension PumpApp on WidgetTester {
  /// Pumps a widget inside a MaterialApp configured the way the real app
  /// configures itself (l10n, ScreenUtil, theme).
  ///
  /// Pass `providers` to inject mocked Cubits — they are wrapped in a
  /// MultiBlocProvider above the widget under test.
  ///
  /// Pass `locale` to test AR/RTL rendering.
  Future<void> pumpAppWidget(
    Widget widget, {
    List<BlocProvider>? providers,
    Locale locale = const Locale('en'),
  }) async {
    final wrapped = providers == null
        ? widget
        : MultiBlocProvider(providers: providers, child: widget);

    await pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        builder: (context, child) => MaterialApp(
          locale: locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('ar')],
          home: Scaffold(body: child),
        ),
        child: wrapped,
      ),
    );
    // ScreenUtil + MaterialApp need a settle pass before the widget tree
    // is queryable.
    await pump();
  }
}
