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

      final list = (rows as List)
          .map((e) => VisitReport.fromMap(e as Map<String, dynamic>))
          .toList();

      debugPrint("✅ [VisitReportsService] mapped ${list.length} VisitReport objects");
      return list;
    } catch (e) {
      debugPrint("❌ [VisitReportsService] error: $e");
      return [];
    }
  }

  Future<List<ModularReport>> fetchModularReports({
    required String? userId,
    required String? relativeId,
  }) async {
    if (userId == null && relativeId == null) return [];

    try {
      final response = await _client.rpc('rpc_get_my_shared_reports', params: {
        'p_user_id': userId,
        'p_relative_id': relativeId,
      });

      if (response == null) return [];
      final list = response as List<dynamic>;
      return list
          .map((e) => ModularReport.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      debugPrint('❌ [VisitReportsService.fetchModularReports] error: $e');
      return [];
    }
  }
}
