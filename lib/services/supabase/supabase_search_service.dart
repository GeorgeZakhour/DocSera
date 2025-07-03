import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseSearchService {
  final SupabaseClient _client = Supabase.instance.client;

  /// 🔍 **Search doctors by name, specialty, or clinic**
  Future<List<Map<String, dynamic>>> searchDoctors(String query) async {
    try {
      if (query.isEmpty) return [];

      final List doctors = await _client
          .from('doctors')
          .select('*');

      String lowerQuery = query.toLowerCase();

      List<Map<String, dynamic>> filteredDoctors = doctors.where((doctor) {
        final fullName = "${doctor['first_name']} ${doctor['last_name']}".toLowerCase();
        final specialty = (doctor['specialty'] ?? "").toLowerCase();
        final clinic = (doctor['clinic'] ?? "").toLowerCase();

        return fullName.contains(lowerQuery) ||
            specialty.contains(lowerQuery) ||
            clinic.contains(lowerQuery);
      }).map((e) => e as Map<String, dynamic>).toList();

      return filteredDoctors;
    } catch (e) {
      print("❌ Error searching doctors: $e");
      return [];
    }
  }
}
