// =============================================================================
// Legal versions checker — fetches docsera.app/legal/versions.json on app
// foreground and compares to the user's accepted versions. If any required
// document has a newer version than the user accepted, returns a list of
// docs the user must re-accept.
//
// Backed by the table public.user_legal_consents and the RPCs
// rpc_record_legal_consent / rpc_get_my_legal_consents.
// =============================================================================

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'legal_consent_service.dart';

class LegalDocumentInfo {
  final String code;
  final String version;
  final String url;
  final bool requiresConsent;

  LegalDocumentInfo({
    required this.code,
    required this.version,
    required this.url,
    required this.requiresConsent,
  });

  static LegalDocumentInfo? fromJson(Map<String, dynamic> j) {
    final code = j['code'];
    final version = j['version'];
    if (code is! String || version is! String) return null;
    return LegalDocumentInfo(
      code: code,
      version: version,
      url: (j['url'] as String?) ?? '',
      requiresConsent: (j['requires_consent'] as bool?) ?? false,
    );
  }
}

class PendingReconsent {
  final List<LegalDocumentInfo> documents;
  PendingReconsent(this.documents);
  bool get isEmpty => documents.isEmpty;
  bool get isNotEmpty => documents.isNotEmpty;
}

class LegalVersionsChecker {
  LegalVersionsChecker._();
  static final LegalVersionsChecker instance = LegalVersionsChecker._();

  static const _versionsUrl = 'https://docsera.app/legal/versions.json';

  /// Cache the latest known manifest so we don't re-fetch on every check.
  /// Stale-while-revalidate: a stale cache is still used; we kick a refresh.
  List<LegalDocumentInfo>? _cached;
  DateTime? _cachedAt;
  Future<List<LegalDocumentInfo>>? _inFlight;

  Future<List<LegalDocumentInfo>> _fetchManifest() async {
    if (_inFlight != null) return _inFlight!;
    _inFlight = _doFetchManifest();
    return _inFlight!;
  }

  Future<List<LegalDocumentInfo>> _doFetchManifest() async {
    try {
      final res = await http
          .get(Uri.parse(_versionsUrl))
          .timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return _cached ?? <LegalDocumentInfo>[];
      final body = jsonDecode(res.body);
      if (body is! Map || body['documents'] is! List) {
        return _cached ?? <LegalDocumentInfo>[];
      }
      final docs = (body['documents'] as List)
          .whereType<Map<String, dynamic>>()
          .map(LegalDocumentInfo.fromJson)
          .whereType<LegalDocumentInfo>()
          .toList(growable: false);
      _cached = docs;
      _cachedAt = DateTime.now();
      return docs;
    } catch (e) {
      if (kDebugMode) debugPrint('[Legal] versions fetch failed: $e');
      return _cached ?? <LegalDocumentInfo>[];
    } finally {
      _inFlight = null;
    }
  }

  /// Returns the documents the current user must re-accept.
  /// Returns empty if not authenticated, the manifest is unreachable, or
  /// the user is up-to-date on every required document.
  Future<PendingReconsent> findPending() async {
    if (Supabase.instance.client.auth.currentUser == null) {
      return PendingReconsent(const []);
    }

    final manifest = await _fetchManifest();
    if (manifest.isEmpty) return PendingReconsent(const []);

    final accepted = await LegalConsentService.instance.getMyConsents();
    final acceptedByCode = <String, Set<String>>{};
    for (final row in accepted) {
      final c = row['document_code'];
      final v = row['version'];
      if (c is String && v is String) {
        acceptedByCode.putIfAbsent(c, () => <String>{}).add(v);
      }
    }

    final pending = <LegalDocumentInfo>[];
    for (final doc in manifest) {
      if (!doc.requiresConsent) continue;
      final accepts = acceptedByCode[doc.code];
      if (accepts == null || !accepts.contains(doc.version)) {
        pending.add(doc);
      }
    }
    return PendingReconsent(pending);
  }

  /// Convenience: record acceptance for all currently-pending documents
  /// at the current versions from the manifest.
  Future<void> recordAcceptanceForPending(PendingReconsent pending) async {
    final byCode = <String, String>{};
    for (final doc in pending.documents) {
      byCode[doc.code] = doc.version;
    }
    if (byCode.isEmpty) return;
    await LegalConsentService.instance.recordConsentForAll(byCode);
  }
}
