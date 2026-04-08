import 'package:supabase_flutter/supabase_flutter.dart';

class SpecialtiesService {
  static List<Map<String, dynamic>>? _cache;

  /// Fetch all active specialties from DB. Cached in memory.
  static Future<List<Map<String, dynamic>>> getAll({bool forceRefresh = false}) async {
    if (_cache != null && !forceRefresh) return _cache!;

    final response = await Supabase.instance.client
        .from('specialties')
        .select('key, name_en, name_ar, icon_key, category, sort_order')
        .eq('is_active', true)
        .order('category')
        .order('sort_order');

    _cache = List<Map<String, dynamic>>.from(response);
    return _cache!;
  }

  /// Get the localized name for a specialty key.
  /// Falls back to the key itself if not found.
  static Future<String> getLocalizedName(String key, String languageCode) async {
    final all = await getAll();
    for (final s in all) {
      if (s['key'] == key) {
        return languageCode == 'ar' ? (s['name_ar'] ?? key) : (s['name_en'] ?? key);
      }
    }
    return key;
  }

  /// Clear cache.
  static void clearCache() => _cache = null;
}
