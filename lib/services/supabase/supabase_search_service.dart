import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class SupabaseSearchService {
  final SupabaseClient _client;
  SupabaseSearchService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  // 🔎 Text search across name + specialty + clinic (client-side filter)
  Future<List<Map<String, dynamic>>> searchDoctors(
      String query, {
        int limit = 150, // cap to keep payload reasonable
      }) async {
    if (query.trim().isEmpty) return [];
    try {
      final List data = await _client
          .from('doctors')
          .select('*')
          .limit(limit);

      final q = query.toLowerCase();
      return data.where((raw) {
        final d = raw as Map<String, dynamic>;
        final fullName =
        '${(d['first_name'] ?? '')} ${(d['last_name'] ?? '')}'.toLowerCase();
        final specialty = (d['specialty'] ?? '').toLowerCase();
        final clinic = (d['clinic'] ?? '').toLowerCase();
        return fullName.contains(q) ||
            specialty.contains(q) ||
            clinic.contains(q);
      }).cast<Map<String, dynamic>>().toList();
    } catch (e) {
      // ignore/trace as needed
      return [];
    }
  }

  // 🔎 Enhanced Search: Searches doctors by name AND by center names
  Future<List<Map<String, dynamic>>> searchDoctorsExtended(String query) async {
    if (query.trim().isEmpty) return [];
    final q = query.toLowerCase();

    try {
      // 1. Direct search in doctors table
      final directDocs = await searchDoctors(q);

      // 2. Search for matching centers
      final centers = await searchCenters(q);
      if (centers.isEmpty) return directDocs;

      final centerIds = centers.map((c) => c['id']).toList();

      // 3. Get members of these centers
      final List members = await _client
          .from('center_members')
          .select('doctor_id, user_id, role')
          .inFilter('center_id', centerIds)
          .eq('is_active', true);

      if (members.isEmpty) return directDocs;

      final relatedDoctorIds = members
          .where((m) => m['role'] == 'owner' || m['role'] == 'doctor')
          .map((m) => m['doctor_id'] ?? m['user_id'])
          .where((id) => id != null)
          .cast<String>()
          .toSet();

      // 4. Fetch these doctors if not already in directDocs
      final existingIds = directDocs.map((d) => d['id'].toString()).toSet();
      final missingIds = relatedDoctorIds.where((id) => !existingIds.contains(id)).toList();

      if (missingIds.isEmpty) return directDocs;

      final List extraDocsRaw = await _client
          .from('doctors')
          .select('*')
          .inFilter('id', missingIds);
      
      final extraDocs = extraDocsRaw.cast<Map<String, dynamic>>();

      return [...directDocs, ...extraDocs];
    } catch (e) {
      return await searchDoctors(q);
    }
  }

  // 🔎 Center Search (server-side filter for better results)
  Future<List<Map<String, dynamic>>> searchCenters(
      String query, {
        int limit = 100,
      }) async {
    if (query.trim().isEmpty) return [];
    final q = query.trim();
    try {
      // 1. Search by name first as it's the most common
      final List dataByName = await _client
          .from('centers')
          .select('*')
          .neq('type', 'solo')
          .ilike('name', '%$q%')
          .limit(limit);
      
      final List<Map<String, dynamic>> results = dataByName.cast<Map<String, dynamic>>();
      return results;
    } catch (e) {
      return [];
    }
  }

  // 🔎 Unified Search: Returns Doctors + Centers + Doctors from matching Centers
  Future<List<Map<String, dynamic>>> searchUnified(String query) async {
    if (query.trim().isEmpty) return [];
    final q = query.trim().toLowerCase();

    try {
      // 1. Search Doctors
      final doctors = await searchDoctors(q);
      for (var d in doctors) {
        d['search_type'] = 'doctor';
      }

      // 2. Search Centers
      final centers = await searchCenters(q);
      for (var c in centers) {
        c['search_type'] = 'center';
      }

      // 3. Get Doctors from matching Centers
      List<Map<String, dynamic>> teamDoctors = [];
      if (centers.isNotEmpty) {
        final centerIds = centers.map((c) => c['id']).toList();

        final List members = await _client
            .from('center_members')
            .select('doctor_id, role')
            .inFilter('center_id', centerIds)
            .eq('is_active', true);

        if (members.isNotEmpty) {
          final doctorIds = members.map((m) => m['doctor_id']).toList();
          final existingDoctorIds = doctors.map((d) => d['id']).toSet();
          final missingIds = doctorIds.where((id) => id != null && !existingDoctorIds.contains(id)).toList();

          if (missingIds.isNotEmpty) {
            final List extraRaw = await _client
                .from('doctors')
                .select('*')
                .inFilter('id', missingIds);
            teamDoctors = extraRaw.cast<Map<String, dynamic>>().map((d) => {...d, 'search_type': 'doctor'}).toList();
          }
        }
      }

      // Merge all (Centers first for visibility if name matches)
      final all = [...centers, ...doctors, ...teamDoctors];

      // Deduplicate by (type, ID) to avoid any collision risk
      final seen = <String>{};
      final unique = all.where((e) => seen.add('${e['search_type']}_${e['id']}')).toList();

      return unique;
    } catch (e) {
      return [];
    }
  }

  // ⭐ Get user favorites
  Future<List<Map<String, dynamic>>> getFavoriteDoctors(String userId) async {
    try {
      final user = await _client
          .from('users')
          .select('favorites')
          .eq('id', userId)
          .single();

      final favIds = (user['favorites'] as List?)?.cast<dynamic>() ?? [];
      if (favIds.isEmpty) return [];

      final List docs = await _client
          .from('doctors')
          .select('*')
          .inFilter('id', favIds);

      return docs.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  // 🏙️ Specialty + City (server-side filter)
  Future<List<Map<String, dynamic>>> fetchBySpecialtyAndCity({
    required String specialty,
    required String cityAr, // value stored in DB (Arabic as per your schema)
    int limit = 200,
  }) async {
    if (specialty.trim().isEmpty || cityAr.trim().isEmpty) return [];
    try {
      final List data = await _client
          .from('doctors')
          .select('*')
          .ilike('specialty', '%$specialty%')
          .eq('address->>city', cityAr)
          .limit(limit);

      return data.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  // 🏙️ Center Specialty + City
  Future<List<Map<String, dynamic>>> fetchCentersBySpecialtyAndCity({
    required String specialty,
    required String cityAr,
    int limit = 150,
  }) async {
    if (specialty.trim().isEmpty || cityAr.trim().isEmpty) return [];
    try {
      final List data = await _client
          .from('centers')
          .select('*')
          .neq('type', 'solo')
          .contains('specialties', [specialty])
          .eq('address->>city', cityAr)
          .limit(limit);

      return data.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  // 📍 Specialty + Nearby (client-side distance + optional radius)
  Future<List<Map<String, dynamic>>> fetchBySpecialtyNearby({
    required String specialty,
    required double userLat,
    required double userLng,
    double? radiusKm, // if provided, filter within this radius
    int limit = 400,   // get a wider set, then sort/filter on client
  }) async {
    if (specialty.trim().isEmpty) return [];
    try {
      final List data = await _client
          .from('doctors')
          .select('*')
          .ilike('specialty', '%$specialty%')
          .limit(limit);

      const Distance dist = Distance();
      final origin = LatLng(userLat, userLng);

      // attach _distanceKm and filter unknown coords
      final withDistance = data.map<Map<String, dynamic>>((raw) {
        final d = raw as Map<String, dynamic>;
        final lat = (d['location']?['lat'] ?? d['lat'])?.toDouble();
        final lng = (d['location']?['lng'] ?? d['lng'])?.toDouble();
        double? km;
        if (lat != null && lng != null) {
          km = dist.as(LengthUnit.Kilometer, origin, LatLng(lat, lng));
        }
        return {...d, '_distanceKm': km};
      }).where((d) => d['_distanceKm'] != null).toList();

      // optional radius filter
      final filtered = radiusKm == null
          ? withDistance
          : withDistance.where((d) => (d['_distanceKm'] as double) <= radiusKm).toList();

      // sort by distance
      filtered.sort((a, b) =>
          (a['_distanceKm'] as double).compareTo(b['_distanceKm'] as double));

      return filtered;
    } catch (_) {
      return [];
    }
  }

  // 📍 Center Specialty + Nearby
  Future<List<Map<String, dynamic>>> fetchCentersBySpecialtyNearby({
    required String specialty,
    required double userLat,
    required double userLng,
    double? radiusKm,
    int limit = 300,
  }) async {
    if (specialty.trim().isEmpty) return [];
    try {
      final List data = await _client
          .from('centers')
          .select('*')
          .neq('type', 'solo')
          .contains('specialties', [specialty])
          .limit(limit);

      const Distance dist = Distance();
      final origin = LatLng(userLat, userLng);

      final withDistance = data.map<Map<String, dynamic>>((raw) {
        final c = raw as Map<String, dynamic>;
        final lat = (c['location']?['lat'] ?? c['lat'])?.toDouble();
        final lng = (c['location']?['lng'] ?? c['lng'])?.toDouble();
        double? km;
        if (lat != null && lng != null) {
          km = dist.as(LengthUnit.Kilometer, origin, LatLng(lat, lng));
        }
        return {...c, '_distanceKm': km};
      }).where((c) => c['_distanceKm'] != null).toList();

      final filtered = radiusKm == null
          ? withDistance
          : withDistance.where((c) => (c['_distanceKm'] as double) <= radiusKm).toList();

      filtered.sort((a, b) =>
          (a['_distanceKm'] as double).compareTo(b['_distanceKm'] as double));

      return filtered;
    } catch (_) {
      return [];
    }
  }
}
