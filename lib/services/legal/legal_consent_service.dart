// =============================================================================
// Legal-consent service — tracks which user has accepted which legal document
// at which version. The corresponding RPCs and the user_legal_consents table
// were created in migration 20260505110000_user_legal_consents.sql.
//
// Public legal documents and their effective versions are listed in the
// /legal/versions.json file served from docsera.app. The app fetches that
// file at startup to detect when a user must re-consent because of a new
// version.
//
// Document codes (must match versions.json):
//   - privacy_policy
//   - terms_of_service
//   - medical_disclaimer
//   - report_illicit_content   (informational only — no consent required)
// =============================================================================

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LegalDocumentCodes {
  LegalDocumentCodes._();
  static const privacyPolicy        = 'privacy_policy';
  static const termsOfService       = 'terms_of_service';
  static const medicalDisclaimer    = 'medical_disclaimer';
  static const reportIllicitContent = 'report_illicit_content';

  /// Documents that require explicit user consent at signup and on version
  /// bumps. report_illicit_content is informational and not in this list.
  static const requiresConsent = <String>[
    privacyPolicy,
    termsOfService,
    medicalDisclaimer,
  ];
}

class LegalConsentService {
  LegalConsentService._();
  static final LegalConsentService instance = LegalConsentService._();

  SupabaseClient get _supabase => Supabase.instance.client;

  /// Record that the current user has accepted a specific document version.
  /// Idempotent — safe to call repeatedly.
  Future<void> recordConsent({
    required String documentCode,
    required String version,
  }) async {
    try {
      String? appVersion;
      String? platform;
      String? locale;
      try {
        final pkg = await PackageInfo.fromPlatform();
        appVersion = '${pkg.version}+${pkg.buildNumber}';
      } catch (_) {/* best-effort metadata */}
      try {
        if (Platform.isIOS) {
          platform = 'ios';
        } else if (Platform.isAndroid) {
          platform = 'android';
        }
      } catch (_) {}
      try {
        locale = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
      } catch (_) {}

      await _supabase.rpc('rpc_record_legal_consent', params: {
        'p_document_code': documentCode,
        'p_version'      : version,
        'p_app_version'  : appVersion,
        'p_platform'     : platform,
        'p_locale'       : locale,
      });
    } catch (e) {
      // Never block the user on consent recording errors — the consent
      // attempt itself is the legally significant action; the database
      // record is the audit trail. We retry on next foreground event.
      if (kDebugMode) debugPrint('[Legal] consent record failed: $e');
    }
  }

  /// Record consent for all required documents at the current versions.
  /// Called from the signup flow after the user ticks the consent boxes.
  Future<void> recordConsentForAll(Map<String, String> versionsByCode) async {
    for (final code in LegalDocumentCodes.requiresConsent) {
      final v = versionsByCode[code];
      if (v == null) continue;
      await recordConsent(documentCode: code, version: v);
    }
  }

  /// Returns the list of document/version pairs the current user has accepted.
  Future<List<Map<String, dynamic>>> getMyConsents() async {
    try {
      final res = await _supabase.rpc('rpc_get_my_legal_consents');
      if (res is List) {
        return res.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Legal] fetch consents failed: $e');
    }
    return const [];
  }

  /// Document URLs (used by the in-app "View Privacy Policy" links).
  static const Map<String, String> documentUrls = {
    LegalDocumentCodes.privacyPolicy:        'https://docsera.app/privacy-policy/',
    LegalDocumentCodes.termsOfService:       'https://docsera.app/terms-of-service/',
    LegalDocumentCodes.medicalDisclaimer:    'https://docsera.app/medical-disclaimer/',
    LegalDocumentCodes.reportIllicitContent: 'https://docsera.app/report-illicit-content/',
  };

  /// Localized URL — appends ?lang=ar or ?lang=en.
  static String urlFor(String documentCode, String localeCode) {
    final base = documentUrls[documentCode];
    if (base == null) return 'https://docsera.app/';
    final lang = (localeCode == 'ar' || localeCode == 'en') ? localeCode : 'ar';
    return '$base?lang=$lang';
  }
}
