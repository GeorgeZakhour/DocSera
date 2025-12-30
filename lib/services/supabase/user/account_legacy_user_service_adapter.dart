import 'package:docsera/services/supabase/user/supabase_user_service.dart';

/// Adapter مؤقت حتى لا يستخدم Account الـ SupabaseUserService مباشرة.
/// لاحقًا نحذفه بعد Migration كامل.
class AccountLegacyUserServiceAdapter {
  final SupabaseUserService _legacy;

  AccountLegacyUserServiceAdapter(this._legacy);

  // مثال: إذا صفحة الحساب تعرض المفضلات أو تحتاج كاش معيّن
  Future<List<String>> getUserFavorites(String userId) {
    return _legacy.getUserFavorites(userId);
  }

  Future<void> updateUserFavorites(String userId, List<String> favorites) {
    return _legacy.updateUserFavorites(userId, favorites);
  }

  Future<List<dynamic>> loadCachedData(String key) {
    return _legacy.loadCachedData(key);
  }

  Future<void> saveCachedData(String key, List<Map<String, dynamic>> data) {
    return _legacy.saveCachedData(key, data);
  }

// لا تنقل deleteUserAccount هنا إطلاقًا
// الحذف يجب أن يذهب لـ AccountDangerService (Edge Function)
}
