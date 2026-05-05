import 'dart:async';
import 'dart:developer';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:docsera/screens/doctors/doctor_profile_page.dart';
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
    String? doctorToken;

    // docsera://doctor/<public_token>
    if (uri.scheme == 'docsera') {
      if (uri.host == 'doctor' && uri.pathSegments.isNotEmpty) {
        doctorToken = uri.pathSegments.first;
      }
    }

    // https://docsera.app/doctor/<public_token>
    if (uri.scheme.startsWith('http')) {
      if (uri.pathSegments.length >= 2 && uri.pathSegments.first == 'doctor') {
        doctorToken = uri.pathSegments[1];
      }
    }

    if (doctorToken == null || doctorToken.isEmpty) {
      log('⚠️ Ignored deep link');
      return;
    }
    // Defense: bound length and charset before issuing a DB query.
    // See [isValidDoctorToken] for the canonical validator.
    if (!isValidDoctorToken(doctorToken)) {
      log('⚠️ Rejected deep link with invalid token shape');
      return;
    }

    _resolveDoctorByPublicToken(doctorToken);
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
}
