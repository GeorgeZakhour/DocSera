import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  // 🔎 Center Search (client-side filter)
  Future<List<Map<String, dynamic>>> searchCenters(
      String query, {
        int limit = 100,
      }) async {
    if (query.trim().isEmpty) return [];
    try {
      final List data = await _client
          .from('centers')
          .select('*')
          .limit(limit);

      final q = query.toLowerCase();
      return data.where((raw) {
        final c = raw as Map<String, dynamic>;
        final name = (c['name'] ?? '').toString().toLowerCase();
        final specialties = (c['specialties'] as List?)?.join(' ').toLowerCase() ?? '';
        return name.contains(q) || specialties.contains(q);
      }).cast<Map<String, dynamic>>().toList();
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
