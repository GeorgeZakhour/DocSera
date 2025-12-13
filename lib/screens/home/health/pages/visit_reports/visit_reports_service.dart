import 'package:supabase_flutter/supabase_flutter.dart';
import 'visit_report_model.dart';

class VisitReportsService {
  final _client = Supabase.instance.client;

  Future<List<VisitReport>> fetchReports({
    required String? userId,
    required String? relativeId,
  }) async {
    print("🛰 [VisitReportsService.fetchReports] called with "
        "userId=$userId, relativeId=$relativeId");

    if (userId == null && relativeId == null) {
      print("⚠️ [VisitReportsService] both userId and relativeId are null → returning empty list");
      return [];
    }

    final filterField = relativeId != null ? "relative_id" : "user_id";
    final filterValue = relativeId ?? userId;

    print("🔎 [VisitReportsService] applying filter: $filterField = $filterValue");

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

      print("📦 [VisitReportsService] Supabase returned ${rows.length} rows");

      for (final row in (rows as List).take(10)) {
        print("  • row id=${row["id"]} "
            "user_id=${row["user_id"]} "
            "relative_id=${row["relative_id"]} "
            "hasReport=${row["report"] != null}");
      }

      final list = (rows as List)
          .map((e) => VisitReport.fromMap(e as Map<String, dynamic>))
          .toList();

      print("✅ [VisitReportsService] mapped ${list.length} VisitReport objects");
      return list;
    } catch (e) {
      print("❌ [VisitReportsService] error: $e");
      return [];
    }
  }
}
