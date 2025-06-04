// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.


import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:docsera/main.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // بناء التطبيق وتمرير اللغة الافتراضية
    await tester.pumpWidget(const MyApp(savedLocale: 'en'));

    // التحقق من أن العداد يبدأ من 0.
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    // النقر على زر '+' وتحديث الواجهة.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    // التحقق من أن العداد أصبح 1.
    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });
}
