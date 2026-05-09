// App-open gate: when the patient lands on MainScreen and has any
// pending patient_link_requests, push the review page for the most
// recent one automatically. Connection / merge requests are
// high-stakes and shouldn't sit silently in the inbox waiting to be
// noticed — they need to be in the user's face.
//
// Cadence: fires once per MainScreen mount (i.e., per cold start /
// per fresh sign-in). Normal background→foreground doesn't trigger
// initState, so the user isn't re-prompted every time they tab back
// to the app.
//
// Skips silently if:
//   * The user already has the review page open (e.g., they tapped a
//     notification before this gate ran).
//   * There are no pending requests.
//   * The fetch fails (best-effort surface — the inbox notification
//     is still there as a fallback).

import 'package:flutter/material.dart';

import 'package:docsera/screens/home/connections/link_request_review_page.dart';
import 'package:docsera/services/supabase/patient_link_requests_service.dart';

/// Single-fire guard so the gate doesn't re-trigger if MainScreen
/// rebuilds for unrelated reasons. Reset on sign-out by the auth
/// flow if needed in the future.
bool _gateFiredThisSession = false;

/// Resets the once-per-session guard. Called from sign-out paths so
/// the next sign-in fires the gate again.
void resetLinkRequestGate() {
  _gateFiredThisSession = false;
}

Future<void> maybeShowPendingLinkRequest(BuildContext context) async {
  if (_gateFiredThisSession) return;
  _gateFiredThisSession = true;

  try {
    final service = PatientLinkRequestsService();
    final pending = await service.fetchPending();
    if (pending.isEmpty) return;
    if (!context.mounted) return;

    // Don't prompt if the user is already on the review page (e.g.,
    // they tapped a deep-link notification before this gate's await
    // resolved).
    final route = ModalRoute.of(context);
    final currentRouteName = route?.settings.name ?? '';
    if (currentRouteName.contains('LinkRequestReviewPage')) return;

    // Show the most recent pending request first. Multiple-request
    // chaining (show-next-on-close) is intentionally deferred — the
    // user can find the rest via their inbox.
    final req = pending.first;

    // Schedule the navigation outside the current frame so the gate
    // doesn't fight any in-flight navigation (e.g., a deep-link push
    // started by a notification tap).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (_) => LinkRequestReviewPage(requestId: req.id),
        ),
      );
    });
  } catch (_) {
    // Best-effort. The inbox notification still surfaces the request
    // through the normal channel.
  }
}
