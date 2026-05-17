import 'dart:async';
import 'dart:developer';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:docsera/screens/doctors/doctor_profile_page.dart';
import 'package:docsera/screens/centers/center_profile_page.dart';
import 'package:docsera/services/navigation/app_lifecycle.dart';

/// Validates a doctor public_token from a deep link before any DB query.
///
/// Tokens in the DB are short alphanumeric IDs (typically <16 chars).
/// Anything outside `[A-Za-z0-9_-]` of length 1..64 is malicious or
/// malformed and must be rejected at the boundary, not at the DB.
///
/// Security tripwire: changing this regex without updating the
/// corresponding test in test/utils/deep_link_validator_test.dart is
/// almost certainly wrong.
bool isValidDoctorToken(String token) {
  if (token.isEmpty || token.length > 64) return false;
  return RegExp(r'^[A-Za-z0-9_\-]+$').hasMatch(token);
}

/// Validates a center identifier from a deep link before any DB query.
///
/// Unlike doctors (which have short public_tokens), centers are
/// addressed by their UUID `id`. We accept the same broad charset as
/// the doctor validator (`[A-Za-z0-9_-]`, length 1..64) so the same
/// boundary check protects both flows without separate test coverage
/// per format. UUIDs always fit; anything else is malformed.
bool isValidCenterId(String id) {
  if (id.isEmpty || id.length > 64) return false;
  return RegExp(r'^[A-Za-z0-9_\-]+$').hasMatch(id);
}

class DeepLinkService {
  final SupabaseClient _supabase;
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSub;
  final GlobalKey<NavigatorState> navKey;

  DeepLinkService(this._supabase, this.navKey) {
    _appLinks = AppLinks();
  }

  void initDeepLinks() async {
    // 🔹 1) App opened from terminated state
    try {
      final Uri? initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleUri(initialUri);
      }
    } catch (e) {
      log('❌ getInitialAppLink error: $e');
    }

    // 🔹 2) App already running
    _linkSub = _appLinks.uriLinkStream.listen(
      (uri) {
        _handleUri(uri);
      },
      onError: (err) {
        log('❌ uriLinkStream error: $err');
      },
    );
  }

  void dispose() {
    _linkSub?.cancel();
  }

  void _handleUri(Uri uri) {
    // Two supported deep-link shapes, each works for both schemes:
    //   docsera://doctor/<public_token>   →  https://docsera.app/doctor/<public_token>
    //   docsera://center/<uuid>           →  https://docsera.app/center/<uuid>
    final String? doctorToken = _extractSegment(uri, 'doctor');
    if (doctorToken != null) {
      if (!isValidDoctorToken(doctorToken)) {
        log('⚠️ Rejected deep link with invalid doctor token shape');
        return;
      }
      _resolveDoctorByPublicToken(doctorToken);
      return;
    }

    final String? centerId = _extractSegment(uri, 'center');
    if (centerId != null) {
      if (!isValidCenterId(centerId)) {
        log('⚠️ Rejected deep link with invalid center id shape');
        return;
      }
      _resolveCenterById(centerId);
      return;
    }

    log('⚠️ Ignored deep link: $uri');
  }

  /// Returns the token / id after `<kind>` for either supported scheme:
  ///   - `docsera://<kind>/<value>`    → uri.host == kind, pathSegments[0] = value
  ///   - `https://docsera.app/<kind>/<value>` → pathSegments[0] = kind, [1] = value
  /// Returns null when the URI doesn't match the `<kind>` shape.
  String? _extractSegment(Uri uri, String kind) {
    if (uri.scheme == 'docsera' &&
        uri.host == kind &&
        uri.pathSegments.isNotEmpty) {
      final v = uri.pathSegments.first;
      return v.isEmpty ? null : v;
    }
    if (uri.scheme.startsWith('http') &&
        uri.pathSegments.length >= 2 &&
        uri.pathSegments.first == kind) {
      final v = uri.pathSegments[1];
      return v.isEmpty ? null : v;
    }
    return null;
  }

  Future<void> _resolveDoctorByPublicToken(String token) async {
    try {
      // Discovery query — deep links to incomplete profiles fall through
      // to the not-found path via public_doctors filtering.
      final res = await _supabase
          .from('public_doctors')
          .select('id')
          .eq('public_token', token)
          .maybeSingle();

      if (res == null) {
        log('❌ Invalid doctor public_token: $token');
        return;
      }

      final doctorId = res['id'] as String;
      _navigateToDoctor(doctorId);
    } catch (e) {
      log('❌ Failed to resolve doctor token: $e');
    }
  }

  void _navigateToDoctor(String doctorId) async {
    // ✅ Wait for Main Screen because deep link might come during SplashScreen
    await AppLifecycle.waitForAppReady();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final nav = navKey.currentState;
      if (nav == null) return;

      nav.push(
        MaterialPageRoute(
          builder: (_) => DoctorProfilePage(
            doctorId: doctorId,
          ),
        ),
      );
    });
  }

  Future<void> _resolveCenterById(String centerId) async {
    try {
      // Validate the center exists and is publishable via public_centers
      // (active centers only — RLS-safe view). Falls through silently if
      // the link points at a deactivated or non-existent center.
      final res = await _supabase
          .from('public_centers')
          .select('id')
          .eq('id', centerId)
          .maybeSingle();

      if (res == null) {
        log('❌ Invalid center id: $centerId');
        return;
      }

      _navigateToCenter(res['id'] as String);
    } catch (e) {
      log('❌ Failed to resolve center id: $e');
    }
  }

  void _navigateToCenter(String centerId) async {
    // Same lifecycle guard as the doctor path — deep link may arrive
    // during SplashScreen before the navigator is mounted.
    await AppLifecycle.waitForAppReady();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final nav = navKey.currentState;
      if (nav == null) return;

      nav.push(
        MaterialPageRoute(
          builder: (_) => CenterProfilePage(centerId: centerId),
        ),
      );
    });
  }
}
