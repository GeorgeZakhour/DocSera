// App-open gate: when the patient lands on MainScreen and has any
// pending patient_link_requests, push the review page for the most
// recent one automatically. Connection / merge requests are
// high-stakes and shouldn't sit silently in the inbox waiting to be
// noticed — they need to be in the user's face.
//
// Cadence: fires once per app process lifetime once auth is settled
// and a pending request exists. Normal background→foreground doesn't
// re-prompt. Sign-out resets the guard so the next sign-in re-arms.
//
// Skips silently if:
//   * The user already has the review page open (e.g., they tapped a
//     deep-link notification before this gate ran).
//   * There are no pending requests.
//   * The fetch fails (best-effort surface — the inbox notification
//     is still there as a fallback).

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:docsera/screens/home/connections/link_request_review_page.dart';
import 'package:docsera/services/supabase/patient_link_requests_service.dart';

/// Single-fire guard so the gate doesn't re-trigger as auth state
/// changes within a session. Reset on sign-out so the next sign-in
/// re-arms the gate.
bool _gateFiredThisSession = false;

/// Cooperative lock — prevents two near-simultaneous calls (e.g., the
/// initState post-frame check + the AuthCubit BlocListener) from
/// racing the fetch and double-pushing. The first caller wins; the
/// second sees the flag set and exits.
bool _gateInFlight = false;

void resetLinkRequestGate() {
  _gateFiredThisSession = false;
  _gateInFlight = false;
}

Future<void> maybeShowPendingLinkRequest(BuildContext context) async {
  if (_gateFiredThisSession || _gateInFlight) {
    debugPrint('🚪 link-gate: skip (fired=$_gateFiredThisSession inflight=$_gateInFlight)');
    return;
  }
  _gateInFlight = true;
  debugPrint('🚪 link-gate: starting fetchPending');

  try {
    final service = PatientLinkRequestsService();
    final pending = await service.fetchPending();
    debugPrint('🚪 link-gate: fetchPending returned ${pending.length} item(s)');

    if (pending.isEmpty) {
      _gateFiredThisSession = true; // nothing to show; mark done
      return;
    }
    if (!context.mounted) {
      debugPrint('🚪 link-gate: context unmounted — abort');
      return;
    }

    // Don't prompt if the user is already on the review page (e.g.,
    // they tapped a deep-link notification before this gate's await
    // resolved).
    final route = ModalRoute.of(context);
    final currentRouteName = route?.settings.name ?? '';
    if (currentRouteName.contains('LinkRequestReviewPage')) {
      debugPrint('🚪 link-gate: review page already on stack — skip');
      _gateFiredThisSession = true;
      return;
    }

    final req = pending.first;
    debugPrint('🚪 link-gate: pushing review page for ${req.id}');
    _gateFiredThisSession = true;

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
  } catch (e, st) {
    debugPrint('🚪 link-gate: failed — $e\n$st');
    // Best-effort. The inbox notification still surfaces the request
    // through the normal channel. Don't burn the once-per-session flag
    // on transient failures so the next AuthAuthenticated tick retries.
  } finally {
    _gateInFlight = false;
  }
}
