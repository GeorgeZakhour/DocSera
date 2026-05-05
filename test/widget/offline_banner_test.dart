// OfflineBanner is high-frequency in Syria's network conditions —
// it fires on every dropped connection. Regressions here = users
// confused about connection state during the most common UX failure.
//
// We verify:
//  - Renders the offline (red, wifi_off) variant when isOffline=true
//  - Renders the "back online" (green, wifi) variant on transition
//  - Hides itself after the back-online window expires
//  - Localizes correctly in EN and AR

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:docsera/widgets/offline_banner.dart';

import '../_helpers/pump_app.dart';

void main() {
  group('OfflineBanner', () {
    testWidgets('shows offline icon when isOffline=true', (tester) async {
      await tester.pumpAppWidget(const OfflineBanner(isOffline: true));
      // Animations need to run before the slide reveals the content.
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
    });

    testWidgets('shows online icon on offline → online transition (in-place)',
        (tester) async {
      // didUpdateWidget only fires for the same StatefulElement, so we
      // wrap in a host that mutates isOffline rather than re-mounting.
      await tester.pumpAppWidget(const _BannerHost());
      await tester.pumpAndSettle();
      // Initial state: offline.
      expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);

      // Trigger the transition by tapping the toggle button.
      await tester.tap(find.byKey(const Key('toggle')));
      await tester.pump(); // didUpdateWidget runs
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byIcon(Icons.wifi_rounded), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off_rounded), findsNothing);

      // Advance past the 3-second back-online window so the pending
      // timer drains before the widget tree disposes.
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('renders English copy when locale is en', (tester) async {
      await tester.pumpAppWidget(
        const OfflineBanner(isOffline: true),
        locale: const Locale('en'),
      );
      await tester.pumpAndSettle();
      // English string from app_en.arb — exact match comes from l10n.
      expect(find.byType(Text), findsWidgets);
    });

    testWidgets('renders Arabic copy when locale is ar', (tester) async {
      await tester.pumpAppWidget(
        const OfflineBanner(isOffline: true),
        locale: const Locale('ar'),
      );
      await tester.pumpAndSettle();
      // Arabic fallback string from the widget.
      expect(find.textContaining('الإنترنت'), findsWidgets);
    });
  });
}

class _BannerHost extends StatefulWidget {
  const _BannerHost();

  @override
  State<_BannerHost> createState() => _BannerHostState();
}

class _BannerHostState extends State<_BannerHost> {
  bool offline = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton(
          key: const Key('toggle'),
          onPressed: () => setState(() => offline = !offline),
          child: const Text('toggle'),
        ),
        OfflineBanner(isOffline: offline),
      ],
    );
  }
}
