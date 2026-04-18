import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:docsera/utils/shared_prefs_service.dart';
import '../../../utils/time_utils.dart';

class FavoritesRepository {
  final SupabaseClient _supabase;
  final SharedPrefsService _sharedPrefsService = SharedPrefsService();

  FavoritesRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  /// ✅ جلب قائمة IDs الأطباء المفضلين
  Future<List<String>> getUserFavorites(String userId) async {
    try {
      final user = await _supabase
          .from('users')
          .select('favorites')
          .eq('id', userId)
          .maybeSingle();

      if (user != null && user['favorites'] != null) {
        return List<String>.from(user['favorites']);
      }
      return [];
    } catch (e) {
      debugPrint("❌ Error fetching favorites: $e");
      return [];
    }
  }

  /// ✅ تحديث قائمة الأطباء المفضلين
  Future<void> updateUserFavorites(String userId, List<String> favorites) async {
    try {
      final response = await _supabase
          .from('users')
          .update({'favorites': favorites})
          .eq('id', userId);

      if (response.error != null) {
        throw Exception('Error updating favorites: ${response.error!.message}');
      }
    } catch (e) {
      debugPrint("❌ Error updating favorites: $e");
    }
  }

  /// ✅ جلب بيانات الأطباء والمراكز من قائمة المفضلات
  Future<List<Map<String, dynamic>>> getFavoriteDoctors() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      // 1. Fetch raw favorites array from users table
      final user = await _supabase
          .from('users')
          .select('favorites')
          .eq('id', userId)
          .maybeSingle();

      List<String> favIds = [];
      if (user != null && user['favorites'] != null) {
        favIds = List<String>.from(user['favorites']);
      }

      if (favIds.isEmpty) {
        await _sharedPrefsService.saveData('favoriteDoctors', []);
        return [];
      }

      // 2. We don't know initially which IDs are doctors and which are centers.
      // Easiest approach: Query both tables simultaneously using `inFilter`
      final doctorFuture = _supabase.from('doctors').select('*').inFilter('id', favIds);
      final centerFuture = _supabase.from('centers').select('*').inFilter('id', favIds);

      final results = await Future.wait([doctorFuture, centerFuture]);
      final List<dynamic> doctorsRaw = results[0] as List<dynamic>;
      final List<dynamic> centersRaw = results[1] as List<dynamic>;

      // 3. Format Doctors
      final doctors = doctorsRaw
          .map<Map<String, dynamic>>((d) {
        final formatted = _buildDoctorInfo(d as Map<String, dynamic>, d['id'] as String);
        formatted['search_type'] = 'doctor'; // Inject type for UI differentiation
        return formatted;
      }).toList();

      // 4. Format Centers
      final centers = centersRaw
          .map<Map<String, dynamic>>((c) {
        final map = c as Map<String, dynamic>;
        map['search_type'] = 'center'; // Inject type
        return map;
      }).toList();

      // 5. Combine and save to cache
      final combinedFavorites = [...doctors, ...centers];
      
      await _sharedPrefsService.saveData('favoriteDoctors', combinedFavorites);
      return combinedFavorites;

    } catch (e) {
      debugPrint("❌ getFavoriteDoctors failed: $e");
      return [];
    }
  }

  /// ✅ إزالة طبيب من المفضلة
  Future<void> removeDoctorFromFavorites(String userId, String doctorId) async {
    try {
      final currentFavorites = await getUserFavorites(userId);
      final updatedFavorites = currentFavorites.where((id) => id != doctorId).toList();

      await updateUserFavorites(userId, updatedFavorites);
      debugPrint("🗑️ Doctor $doctorId removed from favorites.");
    } catch (e) {
      debugPrint("❌ Error removing doctor from favorites: $e");
      throw Exception("Failed to remove doctor from favorites");
    }
  }

  /// ✅ الاستماع لتحديثات قائمة الأطباء المفضلين في الوقت الحقيقي
  Stream<List<Map<String, dynamic>>> listenToFavoriteDoctors() async* {
    yield await getFavoriteDoctors();

    yield* Stream.periodic(const Duration(seconds: 15))
        .asyncMap((_) => getFavoriteDoctors());
  }

  Map<String, dynamic> _buildDoctorInfo(
      Map<String, dynamic> doctor,
      String doctorId,
      ) {
    final gender = (doctor['gender'] ?? "male").toLowerCase();
    final title  = (doctor['title'] ?? "").toLowerCase();

    String? rawImage = doctor['doctor_image'];
    String? imageUrl;

    if (rawImage != null && rawImage.isNotEmpty) {
      imageUrl = rawImage; // فقط اسم الملف
    }

    // fallback فقط إذا لا يوجد صورة أصلًا
    imageUrl ??= (title == "dr.")
        ? (gender == "female"
        ? 'assets/images/female-doc.webp'
        : 'assets/images/male-doc.webp')
        : (gender == "female"
        ? 'assets/images/female-phys.webp'
        : 'assets/images/male-phys.webp');

    return {
      'id': doctorId,
      'title': doctor['title'] ?? "",
      'first_name': doctor['first_name'] ?? "",
      'last_name': doctor['last_name'] ?? "",
      'specialty': doctor['specialty'] ?? "",
      'doctor_image': imageUrl,
      'gender': gender,
      'clinic': doctor['clinic'] ?? "",
      'phone_number': doctor['phone_number'] ?? "",
      'email': doctor['email'] ?? "",
      'profile_description': doctor['profile_description'] ?? "",
      'specialties': doctor['specialties'] ?? [],
      'address': doctor['address'] ?? {},
      'location': doctor['location'] ?? {},
      'opening_hours': doctor['opening_hours'] ?? {},
      'languages': doctor['languages'] ?? [],
      'messages_enabled': doctor['messages_enabled'] ?? false,
      'messages_access': doctor['messages_access'] ?? 'public',
      'last_updated': doctor['last_updated'] != null
          ? (DocSeraTime.tryParseToSyria(doctor['last_updated'])?.millisecondsSinceEpoch ?? 0)
          : 0,
    };
  }

  /// ✅ تحميل بيانات مخزنة بالكاش
  Future<List<dynamic>> loadCachedData(String key) async {
    try {
      return await _sharedPrefsService.loadData(key) ?? [];
    } catch (e) {
      debugPrint("❌ Error loading cached data ($key): $e");
      return [];
    }
  }

  /// ✅ حفظ بيانات بالكاش
  Future<void> saveCachedData(String key, List<Map<String, dynamic>> data) async {
    try {
      await _sharedPrefsService.saveData(key, data);
      debugPrint("✅ [$key] Data saved.");
    } catch (e) {
      debugPrint("❌ Error saving cached data ($key): $e");
    }
  }
}
