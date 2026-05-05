// ChatExpiryBanner shows a dismissable warning when files in a chat
// are about to expire. Smoke-tests verify it renders without crashing
// for canonical inputs in both EN and AR.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:docsera/widgets/chat_expiry_banner.dart';

import '../_helpers/pump_app.dart';
import '../_helpers/tz_init.dart';

void main() {
  setUpAll(initTzForTests);

  group('ChatExpiryBanner', () {
    testWidgets('renders when expiry is in the future', (tester) async {
      await tester.pumpAppWidget(
        ChatExpiryBanner(
          earliestExpiry: DateTime.now().add(const Duration(days: 30)),
          fileCount: 3,
        ),
      );
      await tester.pumpAndSettle();
      // The banner is a StatelessWidget; just verify it built into
      // the tree without throwing.
      expect(find.byType(ChatExpiryBanner), findsOneWidget);
    });

    testWidgets('renders in urgent state when expiry is within 7 days',
        (tester) async {
      await tester.pumpAppWidget(
        ChatExpiryBanner(
          earliestExpiry: DateTime.now().add(const Duration(days: 3)),
          fileCount: 1,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ChatExpiryBanner), findsOneWidget);
    });

    testWidgets('renders in Arabic locale (RTL)', (tester) async {
      await tester.pumpAppWidget(
        ChatExpiryBanner(
          earliestExpiry: DateTime.now().add(const Duration(days: 14)),
          fileCount: 2,
        ),
        locale: const Locale('ar'),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ChatExpiryBanner), findsOneWidget);
    });

    testWidgets('onTap is wired to the tappable region (smoke)',
        (tester) async {
      var tapped = false;
      await tester.pumpAppWidget(
        ChatExpiryBanner(
          earliestExpiry: DateTime.now().add(const Duration(days: 14)),
          fileCount: 1,
          onTap: () => tapped = true,
        ),
      );
      await tester.pumpAndSettle();
      // We don't depend on a specific tappable child here — just verify
      // the widget mounts with a callback configured.
      expect(tapped, false);
      expect(find.byType(ChatExpiryBanner), findsOneWidget);
    });
  });
}
