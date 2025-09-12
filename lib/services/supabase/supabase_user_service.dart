import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:docsera/utils/shared_prefs_service.dart';

class SupabaseUserService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final SharedPrefsService _sharedPrefsService = SharedPrefsService();

  // /// ✅ توليد بريد مزيف جديد باستخدام جدول `metadata` في Supabase
  // Future<String> generateNextFakeEmail() async {
  //   final response = await _supabase
  //       .from('metadata')
  //       .select()
  //       .eq('id', 'emailCounter')
  //       .maybeSingle();
  //
  //   if (response == null || response['lastFakeEmailNumber'] == null) {
  //     throw Exception("Metadata not found or corrupted");
  //   }
  //
  //   int currentNumber = response['lastFakeEmailNumber'];
  //   int nextNumber = currentNumber + 1;
  //
  //   final updateResponse = await _supabase
  //       .from('metadata')
  //       .update({'lastFakeEmailNumber': nextNumber})
  //       .eq('id', 'emailCounter');
  //
  //   if (updateResponse.error != null) {
  //     throw Exception("Failed to update counter: ${updateResponse.error!.message}");
  //   }
  //
  //   final padded = nextNumber.toString().padLeft(7, '0');
  //   final fakeEmail = 'user$padded@docsera.com';
  //   print("📬 Generated from counter: $fakeEmail");
  //
  //   return fakeEmail;
  // }

  // /// ✅ التحقق إذا كان البريد المزيف مستخدم
  // Future<bool> isFakeEmailUsedInAuth(String fakeEmail) async {
  //   try {
  //     final result = await _supabase.auth.admin.listUsers(email: fakeEmail);
  //     return result.users.isNotEmpty;
  //   } catch (e) {
  //     return false;
  //   }
  // }

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

  /// ✅ إضافة مستخدم جديد إلى جدول Supabase
  Future<void> addUser(String userId, Map<String, dynamic> userData) async {
    try {
      userData['created_at'] = DateTime.now().toUtc().toIso8601String();
      userData['updated_at'] = DateTime.now().toUtc().toIso8601String();
      userData['id'] = userId;

      await _supabase.from('users').insert(userData);

    } catch (e) {
      throw Exception('Failed to add user: ${e.toString()}');
    }
  }


  /// ✅ جلب بيانات مستخدم حسب ID
  Future<Map<String, dynamic>?> getUserData(String userId) async {
    try {
      final response = await _supabase
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle();

      return response;
    } catch (e) {
      throw Exception('Failed to fetch user data: $e');
    }
  }

  /// ✅ البحث عن مستخدم عبر البريد أو الهاتف
  Future<Map<String, dynamic>> getUserByEmailOrPhone(String input) async {
    try {
      final emailQuery = await _supabase
          .from('users')
          .select()
          .eq('email', input)
          .maybeSingle();

      if (emailQuery != null) return emailQuery;

      final phoneQuery = await _supabase
          .from('users')
          .select()
          .eq('phone_number', input)
          .maybeSingle();

      if (phoneQuery != null) return phoneQuery;

      throw Exception('User not found');
    } catch (e) {
      throw Exception('Error retrieving user: $e');
    }
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

  Map<String, dynamic> _buildDoctorInfo(Map<String, dynamic> doctor, String doctorId) {
    final gender = (doctor['gender'] ?? "male").toLowerCase();
    final title = (doctor['title'] ?? "").toLowerCase();
    String doctorImage = doctor['doctor_image'] ?? "";

    if (doctorImage.isEmpty || !doctorImage.startsWith("http")) {
      doctorImage = (title == "dr.")
          ? (gender == "female"
          ? 'assets/images/female-doc.png'
          : 'assets/images/male-doc.png')
          : (gender == "female"
          ? 'assets/images/female-phys.png'
          : 'assets/images/male-phys.png');
    }

    return {
      'id': doctorId,
      'title': doctor['title'] ?? "",
      'first_name': doctor['first_name'] ?? "",
      'last_name': doctor['last_name'] ?? "",
      'specialty': doctor['specialty'] ?? "",
      'doctor_image': doctorImage,
      'gender': gender,
      'clinic': doctor['clinic'] ?? "",
      'phone_number': doctor['phone_number'] ?? "",
      'email': doctor['email'] ?? "",
      'profile_description': doctor['profile_description'] ?? "",
      'specialties': doctor['specialties'] ?? [],
      'website': doctor['website'] ?? "",
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
  Future<List<Map<String, dynamic>>> getFavoriteDoctors(String userId) async {
    try {
      final favorites = await getUserFavorites(userId);
      if (favorites.isEmpty) return [];

      final List<Map<String, dynamic>> doctors = [];

      final responses = await Future.wait(favorites.map((doctorId) {
        return _supabase.from('doctors').select().eq('id', doctorId).maybeSingle();
      }));

      for (int i = 0; i < responses.length; i++) {
        final doctor = responses[i];
        final doctorId = favorites[i];
        if (doctor != null) {
          final docInfo = _buildDoctorInfo(doctor, doctorId);
          doctors.add(docInfo);
        }
      }


      await _sharedPrefsService.saveData('favoriteDoctors', doctors);
      return doctors;
    } catch (e) {
      print("❌ Error fetching favorite doctors: $e");
      throw Exception("Error fetching favorite doctors: $e");
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
  Stream<List<Map<String, dynamic>>> listenToFavoriteDoctors(String userId) {
    return _supabase
        .from('users')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .asyncMap((event) async {
      if (event.isEmpty || event.first['favorites'] == null) return <Map<String, dynamic>>[];

      final List<String> favoriteIds = List<String>.from(event.first['favorites']);
      List<Map<String, dynamic>> doctors = [];

      for (final doctorId in favoriteIds) {
        final doctor = await _supabase
            .from('doctors')
            .select()
            .eq('id', doctorId)
            .maybeSingle();

        if (doctor != null) {
          String gender = (doctor['gender'] ?? "male").toLowerCase();
          String title = (doctor['title'] ?? "").toLowerCase();
          String doctorImage = doctor['doctor_image'] ?? "";


          doctors.add({
            'id': doctorId,
            'title': doctor['title'] ?? "",
            'first_name': doctor['first_name'] ?? "",
            'last_name': doctor['last_name'] ?? "",
            'specialty': doctor['specialty'] ?? "",
            'doctor_image': doctorImage,
            'gender': gender,
            'clinic': doctor['clinic'] ?? "",
            'phone_number': doctor['phone_number'] ?? "",
            'email': doctor['email'] ?? "",
            'profile_description': doctor['profile_description'] ?? "",
            'specialties': doctor['specialties'] ?? [],
            'website': doctor['website'] ?? "",
            'address': doctor['address'] ?? {},
            'location': doctor['location'] ?? {},
            'opening_hours': doctor['opening_hours'] ?? {},
            'languages': doctor['languages'] ?? [],
            'last_updated': doctor['last_updated'] != null
                ? DateTime.parse(doctor['last_updated']).millisecondsSinceEpoch
                : 0,
          });
        }
      }

      await _sharedPrefsService.saveData('favoriteDoctors', doctors);
      return doctors;
    });
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
      final now = DateTime.now().toLocal();

      List<Map<String, dynamic>> upcoming = [];
      List<Map<String, dynamic>> past = [];

      for (var appt in data) {
        final timestamp = DateTime.tryParse(appt['timestamp'] ?? '') ?? now;

        if (appt.containsKey('booking_timestamp')) {
          appt['booking_timestamp'] = appt['booking_timestamp']?.toString();
        }

        appt['timestamp'] = timestamp.toIso8601String();

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
      final now = DateTime.now().toLocal();
      List<Map<String, dynamic>> all = [];

      for (final appt in event) {
        // ✅ تصفية الحجوزات المؤكدة فقط
        if (appt['booked'] != true) continue;

        final timestamp = DateTime.tryParse(appt['timestamp'] ?? '') ?? now;

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



