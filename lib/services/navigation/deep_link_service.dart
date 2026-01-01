import 'dart:async';
import 'dart:developer';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:docsera/screens/doctors/doctor_profile_page.dart';

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
      log('⚠️ Ignored deep link: $uri');
      return;
    }

    _resolveDoctorByPublicToken(doctorToken);
  }

  Future<void> _resolveDoctorByPublicToken(String token) async {
    try {
      final res = await _supabase
          .from('doctors')
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

  void _navigateToDoctor(String doctorId) {
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
