import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseCenterService {
  final _client = Supabase.instance.client;

  /// Fetch full center profile data
  Future<Map<String, dynamic>?> getCenterData(String centerId) async {
    try {
      return await _client
          .from('centers')
          .select()
          .eq('id', centerId)
          .maybeSingle();
    } catch (e) {
      return null;
    }
  }

  /// Fetch center team (Doctors)
  Future<List<Map<String, dynamic>>> fetchCenterTeam(String centerId) async {
    try {
      // 1. Get all active members for this center
      final List members = await _client
          .from('center_members')
          .select('id, doctor_id, user_id, role')
          .eq('center_id', centerId)
          .eq('is_active', true);

      if (members.isEmpty) return [];

      // 2. Extract doctor IDs (filter for owner/doctor roles)
      final doctorIds = members
          .where((m) => m['role'] == 'owner' || m['role'] == 'doctor')
          .map((m) => m['doctor_id'] ?? m['user_id'])
          .where((id) => id != null)
          .toList();

      if (doctorIds.isEmpty) return [];

      // 3. Fetch doctor profiles
      final List docs = await _client
          .from('doctors')
          .select('*')
          .inFilter('id', doctorIds);

      return docs.cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }
}
