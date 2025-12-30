import 'dart:async';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:docsera/utils/shared_prefs_service.dart';

import '../../../utils/time_utils.dart';

class SupabaseUserService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final SharedPrefsService _sharedPrefsService = SharedPrefsService();


  /// ✅ التحقق مما إذا كان رقم الهاتف موجود مسبقًا في Supabase
  Future<bool> isPhoneNumberExists(String phoneNumber) async {
    print("📞 Checking if phone number exists: $phoneNumber");

    final response = await _supabase
        .from('users')
        .select('id')
        .eq('phone_number', phoneNumber)
        .maybeSingle();

    final exists = response != null;
    print("📊 Matching phone: ${exists ? "FOUND" : "NOT FOUND"}");

    return exists;
  }

/// ✅ إضافة مستخدم جديد إلى جدول Supabase (آمن ضد null)
  /// ✅ إضافة مستخدم جديد (يعتمد على auth.uid)
  Future<void> addUser(Map<String, dynamic> userData) async {
    try {
      // 🕐 timestamps
      userData['created_at'] =
          DateTime.now().toUtc().toIso8601String();
      userData['updated_at'] =
          DateTime.now().toUtc().toIso8601String();

      // 🧹 تنظيف null
      final safeData = <String, dynamic>{};
      userData.forEach((key, value) {
        if (value == null) {
          safeData[key] =
          (key.contains('verified') ||
              key.contains('accepted') ||
              key.contains('checked') ||
              key.contains('enabled'))
              ? false
              : "";
        } else {
          safeData[key] = value;
        }
      });

      print("📤 inserting user:");
      safeData.forEach((k, v) => print("  $k => $v"));

      await _supabase
          .from('users')
          .insert(safeData);

    } catch (e, s) {
      print("❌ addUser failed: $e");
      print(s);
      rethrow;
    }
  }




  /// ✅ جلب بيانات مستخدم حسب ID
  /// ✅ جلب بيانات المستخدم الحالي (من RPC) — لا تمرر userId للـ DB
  Future<Map<String, dynamic>?> getUserData(String userId) async {
    try {
      // ✅ rpc_get_my_user يعتمد على auth.uid() داخل قاعدة البيانات
      final dynamic res = await _supabase.rpc('rpc_get_my_user');

      // Supabase rpc قد يرجع null أو Map أو JSON (dynamic)
      if (res == null) return null;

      if (res is Map<String, dynamic>) {
        return res;
      }
      // في حال رجعت String JSON (حسب إعدادات/نسخ)
      if (res is String) {
        return (jsonDecode(res) as Map).cast<String, dynamic>();
      }

      // أي شكل غير متوقع
      throw Exception('rpc_get_my_user returned unsupported type: ${res.runtimeType}');
    } catch (e) {
      throw Exception('Failed to fetch user data via RPC: $e');
    }
  }

  /// ✅ البحث عن مستخدم عبر البريد أو الهاتف
  /// ✅ Pre-login lookup (works with strict RLS) via RPC
  /// Returns only: email, is_active, user_id
  Future<Map<String, dynamic>> getLoginInfoByEmailOrPhone(String input) async {
    try {
      final identifier = input.trim();

      final dynamic res = await _supabase.rpc(
        'rpc_get_login_info',
        params: {'p_identifier': identifier},
      );

      if (res == null) {
        throw Exception('User not found');
      }

      // Supabase can return either Map or List depending on version/settings
      if (res is List) {
        if (res.isEmpty) throw Exception('User not found');
        return Map<String, dynamic>.from(res.first as Map);
      }

      if (res is Map) {
        return Map<String, dynamic>.from(res);
      }

      throw Exception('rpc_get_login_info returned unsupported type: ${res.runtimeType}');
    } catch (e) {
      throw Exception('Error retrieving login info via RPC: $e');
    }
  }

  Future<Map<String, dynamic>> getMySecurityState() async {
    final res = await _supabase.rpc('rpc_get_my_security_state');

    if (res == null) {
      throw Exception('Security state not found');
    }

    if (res is Map<String, dynamic>) return res;
    if (res is String) return jsonDecode(res) as Map<String, dynamic>;

    throw Exception('Invalid security state response');
  }


  /// ✅ تحديث بيانات مستخدم
  Future<void> updateUser(String userId, Map<String, dynamic> updatedData) async {
    try {
      updatedData['updated_at'] = DateTime.now().toUtc().toIso8601String();

      final response = await _supabase
          .from('users')
          .update(updatedData)
          .eq('id', userId);

      if (response.error != null) {
        throw Exception('Update failed: ${response.error!.message}');
      }
    } catch (e) {
      throw Exception('Failed to update user: ${e.toString()}');
    }
  }
}


extension SupabaseUserServiceFavorites on SupabaseUserService {
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
      print("❌ Error fetching favorites: $e");
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
      print("❌ Error updating favorites: $e");
    }
  }

  /// ✅ التحقق من وجود مستخدم بالبريد أو الهاتف
  Future<bool> doesUserExist({String? email, String? phoneNumber}) async {
    try {
      if (email != null) {
        final emailMatch = await _supabase
            .from('users')
            .select('id')
            .eq('email', email)
            .maybeSingle();
        if (emailMatch != null) return true;
      }

      if (phoneNumber != null) {
        final phoneMatch = await _supabase
            .from('users')
            .select('id')
            .eq('phone_number', phoneNumber)
            .maybeSingle();
        if (phoneMatch != null) return true;
      }

      return false;
    } catch (e) {
      throw Exception('Error checking for duplicates: $e');
    }
  }

  /// ✅ جلب مستخدمين مجزئين (Paginated)
  Future<List<Map<String, dynamic>>> getPaginatedUsers({String? lastCreatedAt, int limit = 10}) async {
    try {
      if (lastCreatedAt != null) {
        final result = await _supabase
            .from('users')
            .select()
            .gt('created_at', lastCreatedAt)
            .order('created_at')
            .limit(limit);
        return List<Map<String, dynamic>>.from(result);
      } else {
        final result = await _supabase
            .from('users')
            .select()
            .order('created_at')
            .limit(limit);
        return List<Map<String, dynamic>>.from(result);
      }
    } catch (e) {
      throw Exception('Error retrieving paginated users: $e');
    }
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
      // 🔥 نفس منطق DoctorProfile
      imageUrl = rawImage; // فقط اسم الملف

    }

    // fallback فقط إذا لا يوجد صورة أصلًا
    imageUrl ??= (title == "dr.")
        ? (gender == "female"
        ? 'assets/images/female-doc.png'
        : 'assets/images/male-doc.png')
        : (gender == "female"
        ? 'assets/images/female-phys.png'
        : 'assets/images/male-phys.png');

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
      'last_updated': doctor['last_updated'] != null
          ? DateTime.parse(doctor['last_updated']).millisecondsSinceEpoch
          : 0,
    };
  }


  /// ✅ جلب بيانات الأطباء من قائمة المفضلات
  /// Query واحد – بدون inFilter – متوافق مع UUID + RLS
  Future<List<Map<String, dynamic>>> getFavoriteDoctors() async {
    try {
      final dynamic res =
      await _supabase.rpc('rpc_get_my_favorite_doctors');

      if (res == null) {
        await _sharedPrefsService.saveData('favoriteDoctors', []);
        return [];
      }

      final List<dynamic> list =
      res is String ? jsonDecode(res) : res;

      final doctors = list
          .map<Map<String, dynamic>>(
            (doctor) => _buildDoctorInfo(
          doctor as Map<String, dynamic>,
          doctor['id'] as String,
        ),
      )
          .toList();

      await _sharedPrefsService.saveData('favoriteDoctors', doctors);
      return doctors;
    } catch (e) {
      print("❌ getFavoriteDoctors failed: $e");
      return [];
    }
  }

  /// ✅ إزالة طبيب من المفضلة
  Future<void> removeDoctorFromFavorites(String userId, String doctorId) async {
    try {
      final currentFavorites = await getUserFavorites(userId);
      final updatedFavorites = currentFavorites.where((id) => id != doctorId).toList();

      await updateUserFavorites(userId, updatedFavorites);
      print("🗑️ Doctor $doctorId removed from favorites.");
    } catch (e) {
      print("❌ Error removing doctor from favorites: $e");
      throw Exception("Failed to remove doctor from favorites");
    }
  }


  /// ✅ الاستماع لتحديثات قائمة الأطباء المفضلين في الوقت الحقيقي
  /// بدون inFilter – آمن مع UUID + RLS
  Stream<List<Map<String, dynamic>>> listenToFavoriteDoctors() async* {
    yield await getFavoriteDoctors();

    yield* Stream.periodic(const Duration(seconds: 15))
        .asyncMap((_) => getFavoriteDoctors());
  }



  /// ✅ تحميل بيانات مخزنة بالكاش
  Future<List<dynamic>> loadCachedData(String key) async {
    try {
      return await _sharedPrefsService.loadData(key) ?? [];
    } catch (e) {
      print("❌ Error loading cached data ($key): $e");
      return [];
    }
  }

  /// ✅ حفظ بيانات بالكاش
  Future<void> saveCachedData(String key, List<Map<String, dynamic>> data) async {
    try {
      await _sharedPrefsService.saveData(key, data);
      print("✅ [$key] Data saved.");
    } catch (e) {
      print("❌ Error saving cached data ($key): $e");
    }
  }
}



StreamSubscription<List<Map<String, dynamic>>>? _appointmentsListener;


extension SupabaseUserServiceAppointments on SupabaseUserService {
  /// ✅ جلب مواعيد المستخدم مع تصنيفها (قادمة / سابقة)
  Future<Map<String, List<Map<String, dynamic>>>> getUserAppointments(String userId) async {
    try {
      // ✅ جلب من الكاش أولًا
      final cachedUpcoming = await _sharedPrefsService.loadData('upcomingAppointments') ?? [];
      final cachedPast = await _sharedPrefsService.loadData('pastAppointments') ?? [];

      if (cachedUpcoming.isNotEmpty || cachedPast.isNotEmpty) {
        print("⚡ Loaded appointments from cache");
        return {
          'upcoming': List<Map<String, dynamic>>.from(cachedUpcoming),
          'past': List<Map<String, dynamic>>.from(cachedPast),
        };
      }

      final response = await _supabase
          .from('appointments')
          .select()
          .eq('user_id', userId)
          .order('timestamp');

      final data = response;
      final now = TimezoneUtils.toDamascus(DateTime.now().toUtc());

      List<Map<String, dynamic>> upcoming = [];
      List<Map<String, dynamic>> past = [];

      for (var appt in data) {
        final status = (appt['status'] ?? '').toString();
        final isRejected = status == 'rejected';
        final isBooked = appt['booked'] == true;

        // ✅ عرض فقط المواعيد المحجوزة أو المرفوضة (وليس المسودة)
        if (!isBooked && !isRejected) continue;

        final timestampUtc = DateTime.tryParse(appt['timestamp'] ?? '')?.toUtc();
        final timestamp = TimezoneUtils.toDamascus(timestampUtc ?? now);

        if (appt.containsKey('booking_timestamp')) {
          appt['booking_timestamp'] = appt['booking_timestamp']?.toString();
        }

        appt['timestamp'] = timestamp.toIso8601String();

        // ✅ تصنيف قادم / سابق
        if (timestamp.isAfter(now)) {
          upcoming.add(appt);
        } else {
          past.add(appt);
        }
      }


      await _sharedPrefsService.saveData('upcomingAppointments', upcoming);
      await _sharedPrefsService.saveData('pastAppointments', past);

      return {
        'upcoming': List<Map<String, dynamic>>.from(upcoming),
        'past': List<Map<String, dynamic>>.from(past),
      };
    } catch (e) {
      print("❌ Error fetching appointments: $e");
      return {'upcoming': [], 'past': []};
    }
  }

  /// ✅ الاستماع للمواعيد في الوقت الفعلي (يتطلب تفعيل Realtime في Supabase)
  Stream<List<Map<String, dynamic>>> listenToUserAppointments(String userId) {
    final stream = _supabase
        .from('appointments')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('timestamp', ascending: true)
        .map((event) {
      final now = TimezoneUtils.toDamascus(DateTime.now().toUtc());
      List<Map<String, dynamic>> all = [];

      for (final appt in event) {
        final status = (appt['status'] ?? '').toString();
        final isRejected = status == 'rejected';
        final isBooked = appt['booked'] == true;

        // ✅ نسمح فقط بالمواعيد المحجوزة أو المرفوضة
        if (!isBooked && !isRejected) continue;



        final timestampUtc = DateTime.tryParse(appt['timestamp'] ?? '')?.toUtc();
        final timestamp = TimezoneUtils.toDamascus(timestampUtc ?? now);

        appt['timestamp'] = timestamp.toIso8601String();
        appt['booking_timestamp'] = appt['booking_timestamp']?.toString();

        all.add(appt);
      }

      final upcoming = all.where((a) => DateTime.parse(a['timestamp']).isAfter(now)).toList();
      final past = all.where((a) => DateTime.parse(a['timestamp']).isBefore(now)).toList();

      _sharedPrefsService.saveData('upcomingAppointments', upcoming);
      _sharedPrefsService.saveData('pastAppointments', past);

      print("🔥 Appointments updated via realtime");

      return [...upcoming, ...past];
    });

    return stream;
  }



  /// ✅ تفعيل الاستماع للمواعيد
  void listenToAppointments(String userId) {
    _appointmentsListener?.cancel();
    _appointmentsListener = listenToUserAppointments(userId).listen((_) {
      print("📡 Appointments listener triggered.");
    });
  }

  /// ✅ إلغاء الاستماع
  void cancelAppointmentsListener() {
    _appointmentsListener?.cancel();
    _appointmentsListener = null;
    print("🛑 Appointments listener canceled.");
  }

  /// ✅ مسح كاش المواعيد
  Future<void> clearAppointmentCache() async {
    await _sharedPrefsService.removeData('upcomingAppointments');
    await _sharedPrefsService.removeData('pastAppointments');
    print("🧹 Appointment cache cleared.");
  }
}


extension SupabaseUserServiceDelete on SupabaseUserService {
  /// ✅ حذف حساب المستخدم وكل ما يتعلق به
  Future<void> deleteUserAccount(String userId, {String? phoneNumber, String? email}) async {
    try {
      print("🔍 Starting account deletion for userId: $userId");

      // 🧽 حذف الملاحظات، الوثائق، المواعيد، الأقارب من الجداول المرتبطة
      final subTables = ['appointments', 'documents', 'notes', 'relatives'];
      for (final table in subTables) {
        final res = await _supabase
            .from(table)
            .delete()
            .eq('user_id', userId);
        if (res.error != null) {
          print("⚠️ Error deleting from $table: ${res.error!.message}");
        } else {
          print("🗑️ Deleted from $table");
        }
      }

      // 🧽 حذف الملفات من Supabase Storage
      await _deleteAllFilesUnderUser(userId);

      // 🧽 حذف صف المستخدم
      final userRes = await _supabase
          .from('users')
          .delete()
          .eq('id', userId);
      if (userRes.error != null) {
        print("❌ Failed to delete user row: ${userRes.error!.message}");
        throw Exception("Error deleting user data");
      }

      // 🧽 حذف OTP إذا كانت مخزنة في جداول منفصلة (اختياري)
      if (phoneNumber != null) {
        await _supabase.from('otp').delete().eq('id', phoneNumber);
        print("📞 Deleted phone OTP for $phoneNumber");
      }

      if (email != null) {
        await _supabase.from('email_otp').delete().eq('id', email);
        print("📧 Deleted email OTP for $email");
      }

      // 🔐 حذف حساب المصادقة
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser != null && currentUser.id == userId) {
        await Supabase.instance.client.auth.signOut();
        await Supabase.instance.client.auth.admin.deleteUser(userId);
        print("✅ Supabase Auth user deleted");
      }

      // 🧼 تنظيف SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      print("🧼 SharedPreferences cleared");

      print("✅ Account deletion complete for userId: $userId");

    } catch (e) {
      print("❌ Error deleting user account: $e");
      throw Exception("Failed to delete account");
    }
  }

  /// ✅ حذف جميع الملفات الخاصة بالمستخدم من Supabase Storage
  Future<void> _deleteAllFilesUnderUser(String userId) async {
    final bucket = Supabase.instance.client.storage.from('documents');
    final folderPath = 'users/$userId';
    try {
      final listResult = await bucket.list(path: folderPath);
      for (final file in listResult) {
        await bucket.remove(['$folderPath/${file.name}']);
        print("🗑️ Deleted file: $folderPath/${file.name}");
      }
      print("✅ All files under $folderPath deleted.");
    } catch (e) {
      print("❌ Error deleting user files: $e");
    }
  }
}



