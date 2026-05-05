// Extended text-direction tests covering getTextAlign which routes
// localized labels in lists/forms to the right horizontal alignment.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:docsera/utils/text_direction_utils.dart';

void main() {
  group('getTextAlign', () {
    testWidgets('en locale → TextAlign.left', (tester) async {
      late TextAlign captured;
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('ar')],
        home: Builder(builder: (context) {
          captured = getTextAlign(context);
          return const SizedBox();
        }),
      ));
      expect(captured, TextAlign.left);
    });

    testWidgets('ar locale → TextAlign.right', (tester) async {
      late TextAlign captured;
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('ar')],
        home: Builder(builder: (context) {
          captured = getTextAlign(context);
          return const SizedBox();
        }),
      ));
      expect(captured, TextAlign.right);
    });
  });
}
