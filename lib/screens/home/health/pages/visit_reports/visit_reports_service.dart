import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'visit_report_model.dart';
import 'modular_report_model.dart';

class VisitReportsService {
  final _client = Supabase.instance.client;

  Future<List<VisitReport>> fetchReports({
    required String? userId,
    required String? relativeId,
  }) async {
    debugPrint("🛰 [VisitReportsService.fetchReports] called with "
        "userId=$userId, relativeId=$relativeId");

    if (userId == null && relativeId == null) {
      debugPrint("⚠️ [VisitReportsService] both userId and relativeId are null → returning empty list");
      return [];
    }

    final filterField = relativeId != null ? "relative_id" : "user_id";
    final filterValue = relativeId ?? userId;

    debugPrint("🔎 [VisitReportsService] applying filter: $filterField = $filterValue");

    try {
      final rows = await _client
          .from("appointments")
          .select("""
            id,
            appointment_date,
            doctor_name,
            doctor_specialty,
            clinic,
            clinic_address,
            doctor_gender,
            doctor_title,
            doctor_image,
            report,
            user_id,
            relative_id
          """)
          .eq(filterField, filterValue!)
          .not("report", "is", null);

      debugPrint("📦 [VisitReportsService] Supabase returned ${rows.length} rows");

      for (final row in (rows as List).take(10)) {
        debugPrint("  • row id=${row["id"]} "
            "user_id=${row["user_id"]} "
            "relative_id=${row["relative_id"]} "
            "hasReport=${row["report"] != null}");
      }

      // Filter: skip modular reports (they come via fetchModularReports)
      // and skip reports that haven't been explicitly shared
      final filtered = (rows as List).where((e) {
        final report = e["report"];
        if (report == null) return false;
        if (report is Map) {
          // Skip modular reports — they'll appear via the direct query path
          if (report['sections'] != null) {
            debugPrint("  ⏭ skipping modular report in legacy path: ${e['id']}");
            return false;
          }
          // Skip reports that haven't been explicitly shared
          if (report['shared_with_patient'] == false) {
            debugPrint("  🔒 skipping unshared report: ${e['id']}");
            return false;
          }
        }
        return true;
      }).toList();

      final list = filtered
          .map((e) => VisitReport.fromMap(e as Map<String, dynamic>))
          .toList();

      debugPrint("✅ [VisitReportsService] mapped ${list.length} legacy VisitReport objects (filtered from ${rows.length} rows)");
      return list;
    } catch (e) {
      debugPrint("❌ [VisitReportsService] error: $e");
      return [];
    }
  }

  /// Fetch a single report with full section data (including heavy
  /// body_map/image_comparison values). Used when opening a report detail.
  Future<ModularReport?> fetchFullReport(String reportId) async {
    try {
      final row = await _client
          .from('reports')
          .select()
          .eq('id', reportId)
          .maybeSingle();
      if (row == null) return null;

      // Fetch doctor info
      final doctorId = row['doctor_id']?.toString() ?? '';
      Map<String, dynamic>? doc;
      if (doctorId.isNotEmpty) {
        try {
          doc = await _client
              .from('doctors')
              .select('id, first_name, last_name, specialty, clinic, clinic_address, doctor_image, gender, title, contact_phones, contact_mobile, contact_email, contact_website')
              .eq('id', doctorId)
              .maybeSingle();
        } catch (_) {}
      }

      final firstName = doc?['first_name']?.toString() ?? '';
      final lastName = doc?['last_name']?.toString() ?? '';
      final combined = <String, dynamic>{
        ...Map<String, dynamic>.from(row),
        'doctor_name': '$firstName $lastName'.trim(),
        'doctor_specialty': doc?['specialty'],
        'doctor_clinic': doc?['clinic'],
        'doctor_city': _extractCity(doc?['clinic_address']),
        'doctor_image': doc?['doctor_image'],
        'doctor_gender': doc?['gender'],
        'doctor_title': doc?['title'],
        'doctor_phone': doc?['contact_phones'],
        'doctor_mobile': doc?['contact_mobile'],
        'doctor_email': doc?['contact_email'],
        'doctor_website': doc?['contact_website'],
      };

      return ModularReport.fromJson(combined);
    } catch (e) {
      debugPrint('❌ [fetchFullReport] error: $e');
      return null;
    }
  }

  /// Fetch only heavy sections (body_map, image_comparison) for a single report.
  /// Used for lazy-loading on the detail page after showing lightweight sections.
  Future<List<ModularReportSection>> fetchHeavySections(String reportId) async {
    try {
      final response = await _client.rpc('rpc_get_heavy_sections', params: {
        'p_report_id': reportId,
      });

      List<dynamic> items;
      if (response is List) {
        items = response;
      } else if (response is String) {
        final decoded = jsonDecode(response);
        if (decoded is List) {
          items = decoded;
        } else {
          return [];
        }
      } else {
        return [];
      }

      return items
          .whereType<Map>()
          .map((e) => ModularReportSection.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      debugPrint('❌ [fetchHeavySections] error: $e');
      return [];
    }
  }

  Future<List<ModularReport>> fetchModularReports({
    required String? userId,
    required String? relativeId,
  }) async {
    debugPrint("🛰 [VisitReportsService.fetchModularReports] called with "
        "userId=$userId, relativeId=$relativeId");

    if (userId == null && relativeId == null) {
      debugPrint("⚠️ [VisitReportsService.fetchModularReports] both null → returning empty");
      return [];
    }

    // ── Strategy: try RPC first, fall back to direct query ──
    try {
      final result = await _tryRpc(userId: userId, relativeId: relativeId);
      if (result != null) return result;
    } catch (_) {
      // RPC failed — fall through to direct query
    }

    // ── Fallback: direct query on reports table ──
    // The RLS policy "reports_select_patient" allows SELECT WHERE auth.uid() = user_id
    debugPrint("🔄 [VisitReportsService.fetchModularReports] falling back to direct query");
    return _directQuery(userId: userId, relativeId: relativeId);
  }

  /// Attempt to fetch shared reports via the RPC function.
  /// Returns null if the RPC doesn't exist or fails fundamentally.
  Future<List<ModularReport>?> _tryRpc({
    required String? userId,
    required String? relativeId,
  }) async {
    try {
      final response = await _client.rpc('rpc_get_my_shared_reports', params: {
        'p_user_id': userId,
        'p_relative_id': relativeId,
      });

      debugPrint("📦 [fetchModularReports.RPC] "
          "response type: ${response.runtimeType}, "
          "value preview: ${response.toString().length > 200 ? response.toString().substring(0, 200) : response}");

      if (response == null) {
        debugPrint("⚠️ [fetchModularReports.RPC] response is null");
        return [];
      }

      // Handle multiple possible response formats from RETURNS JSONB
      List<dynamic> items;
      if (response is List) {
        items = response;
      } else if (response is String) {
        // PostgREST may return JSONB as a raw string
        final decoded = jsonDecode(response);
        if (decoded is List) {
          items = decoded;
        } else {
          debugPrint("⚠️ [fetchModularReports.RPC] decoded string is ${decoded.runtimeType}, not List");
          return [];
        }
      } else {
        debugPrint("⚠️ [fetchModularReports.RPC] unexpected type: ${response.runtimeType}");
        return [];
      }

      debugPrint("✅ [fetchModularReports.RPC] parsed ${items.length} shared modular reports");

      for (final item in items.take(5)) {
        if (item is Map) {
          debugPrint("  • report id=${item['id']} "
              "sections_count=${(item['sections'] as List?)?.length ?? 0}");
        }
      }

      return items
          .map((e) => ModularReport.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e, stack) {
      debugPrint('❌ [fetchModularReports.RPC] error: $e');
      debugPrint('   stack: ${stack.toString().split('\n').take(5).join('\n')}');
      // Return null to signal "RPC unavailable, use fallback"
      return null;
    }
  }

  /// Direct query fallback: read shared reports from the reports table.
  /// Works even if the RPC function is not deployed.
  /// Relies on RLS policy: "reports_select_patient" (auth.uid() = user_id).
  Future<List<ModularReport>> _directQuery({
    required String? userId,
    required String? relativeId,
  }) async {
    try {
      // Build the query — fetch reports that are shared with this patient
      // The RPC (fn_strip_heavy_sections) already strips body_map and
      // image_comparison values. For the direct-query fallback, we must
      // include sections so non-heavy sections render instantly.
      // Heavy sections will be lazy-loaded on the detail page.
      var query = _client
          .from('reports')
          .select('''
            id,
            appointment_id,
            doctor_id,
            user_id,
            relative_id,
            patient_name,
            share_mode,
            patient_visible_sections,
            sections,
            created_at,
            updated_at
          ''')
          .eq('shared_with_patient', true);

      // Filter by relative_id or user_id
      if (relativeId != null) {
        query = query.eq('relative_id', relativeId);
      } else if (userId != null) {
        query = query.eq('user_id', userId);
      }

      final rows = await query.order('created_at', ascending: false);

      debugPrint("📦 [fetchModularReports.DirectQuery] returned ${(rows as List).length} rows");

      if (rows.isEmpty) return [];

      // Now fetch doctor info for these reports
      final doctorIds = (rows as List)
          .map((r) => r['doctor_id']?.toString())
          .where((id) => id != null && id.isNotEmpty)
          .toSet()
          .toList();

      Map<String, Map<String, dynamic>> doctorMap = {};
      if (doctorIds.isNotEmpty) {
        try {
          final doctors = await _client
              .from('doctors')
              .select('id, first_name, last_name, specialty, clinic, clinic_address, doctor_image, gender, title, contact_phones, contact_mobile, contact_email, contact_website')
              .inFilter('id', doctorIds);

          for (final doc in (doctors as List)) {
            doctorMap[doc['id'].toString()] = Map<String, dynamic>.from(doc);
          }
        } catch (e) {
          debugPrint("⚠️ [fetchModularReports.DirectQuery] couldn't fetch doctor info: $e");
        }
      }

      // Also fetch patient info
      String? patientGender;
      String? patientDob;
      String? patientPhone;
      try {
        if (relativeId != null) {
          final rel = await _client
              .from('relatives')
              .select('gender, date_of_birth')
              .eq('id', relativeId)
              .maybeSingle();
          if (rel != null) {
            patientGender = rel['gender']?.toString();
            patientDob = rel['date_of_birth']?.toString();
          }
        } else if (userId != null) {
          final user = await _client
              .from('users')
              .select('gender, date_of_birth, phone_number')
              .eq('id', userId)
              .maybeSingle();
          if (user != null) {
            patientGender = user['gender']?.toString();
            patientDob = user['date_of_birth']?.toString();
            patientPhone = user['phone_number']?.toString();
          }
        }
      } catch (e) {
        debugPrint("⚠️ [fetchModularReports.DirectQuery] couldn't fetch patient info: $e");
      }

      final reports = (rows as List).map((row) {
        final doctorId = row['doctor_id']?.toString() ?? '';
        final doc = doctorMap[doctorId];
        final firstName = doc?['first_name']?.toString() ?? '';
        final lastName = doc?['last_name']?.toString() ?? '';
        final doctorName = '$firstName $lastName'.trim();

        // Build a combined JSON matching the RPC output shape
        final combined = <String, dynamic>{
          ...Map<String, dynamic>.from(row),
          'doctor_name': doctorName,
          'doctor_specialty': doc?['specialty'],
          'doctor_clinic': doc?['clinic'],
          'doctor_city': _extractCity(doc?['clinic_address']),
          'doctor_image': doc?['doctor_image'],
          'doctor_gender': doc?['gender'],
          'doctor_title': doc?['title'],
          'doctor_phone': doc?['contact_phones'],
          'doctor_mobile': doc?['contact_mobile'],
          'doctor_email': doc?['contact_email'],
          'doctor_website': doc?['contact_website'],
          'patient_gender': patientGender,
          'patient_dob': patientDob,
          'patient_phone': patientPhone,
        };

        // Strip heavy sections client-side to match the RPC behavior
        return ModularReport.fromJson(combined, stripHeavy: true);
      }).toList();

      debugPrint("✅ [fetchModularReports.DirectQuery] mapped ${reports.length} ModularReport objects");
      return reports;
    } catch (e, stack) {
      debugPrint('❌ [fetchModularReports.DirectQuery] error: $e');
      debugPrint('   stack: ${stack.toString().split('\n').take(5).join('\n')}');
      return [];
    }
  }

  String _extractCity(dynamic clinicAddress) {
    if (clinicAddress == null) return '';
    if (clinicAddress is Map) return clinicAddress['city']?.toString() ?? '';
    if (clinicAddress is String) return clinicAddress;
    return '';
  }
}
