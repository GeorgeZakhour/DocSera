import 'dart:async';
import 'dart:convert';
import 'package:docsera/Business_Logic/Account_page/user_cubit.dart';
import 'package:docsera/utils/time_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


class SharedPrefsService {
  static final SharedPrefsService _instance = SharedPrefsService._internal();
  factory SharedPrefsService() => _instance;
  SharedPrefsService._internal();

  final StreamController<List<Map<String, dynamic>>> _favoriteDoctorsController = StreamController.broadcast();
  Stream<List<Map<String, dynamic>>> get favoriteDoctorsStream => _favoriteDoctorsController.stream;

  final StreamController<Map<String, List<Map<String, dynamic>>>> _appointmentsController = StreamController.broadcast();
  Stream<Map<String, List<Map<String, dynamic>>>> get appointmentsStream => _appointmentsController.stream;

  final StreamController<Map<String, dynamic>> _userProfileController = StreamController.broadcast();
  Stream<Map<String, dynamic>> get userProfileStream => _userProfileController.stream;

  Future<SharedPreferences> _prefs() async => await SharedPreferences.getInstance();

  /// ✅ **حفظ بيانات كـ JSON في SharedPreferences**
  Future<void> saveData(String key, dynamic data) async {
    final prefs = await _prefs();

    // ✅ Store boolean values directly instead of converting to JSON
    if (key == 'refreshFavorites' || key == 'refreshAppointments' || key == 'isLoggedIn') {
      if (data is bool) {
        await prefs.setBool(key, data);
        debugPrint("✅ [$key] Boolean flag set to: $data");
      } else {
        debugPrint("⚠️ [$key] Invalid boolean value provided: $data");
      }
      return;
    }

    String jsonData = json.encode(data);
    await prefs.setString(key, jsonData);
    debugPrint("✅ [$key] Data saved.");
  }

  /// ✅ **تحميل البيانات المحفوظة وتحويلها إلى JSON مع التحقق من النوع**
  Future<dynamic> loadData(String key) async {
    final prefs = await _prefs();

    // ✅ Handle boolean flags separately
    if (key == 'refreshFavorites' || key == 'refreshAppointments' || key == 'isLoggedIn') {
      return prefs.getBool(key) ?? false;
    }

    String? jsonData = prefs.getString(key);
    if (jsonData == null) {
      debugPrint("⚠️ [$key] No cached data found.");
      return null;
    }

    try {
      var decodedData = json.decode(jsonData);

      // ✅ Convert timestamp fields back to `DateTime`
      void convertBackTimestamps(dynamic data) {
        if (data is Map<String, dynamic>) {
          data.forEach((key, value) {
            if (value is int && (key.contains("timestamp") || key.contains("lastUpdated"))) {
              data[key] = DateTime.fromMillisecondsSinceEpoch(value);
            } else if (value is Map<String, dynamic> || value is List) {
              convertBackTimestamps(value); // Recursive call for nested fields
            }
          });
        } else if (data is List) {
          for (int i = 0; i < data.length; i++) {
            if (data[i] is int) {
              data[i] = DateTime.fromMillisecondsSinceEpoch(data[i]);
            } else if (data[i] is Map<String, dynamic> || data[i] is List) {
              convertBackTimestamps(data[i]); // Recursive call for nested fields
            }
          }
        }
      }

      convertBackTimestamps(decodedData);
      return decodedData;
    } catch (e) {
      debugPrint("❌ [$key] Error decoding JSON: $e");
      return null;
    }
  }

  /// ✅ **حذف بيانات مخزنة**
  Future<void> removeData(String key) async {
    final prefs = await _prefs();
    await prefs.remove(key);
  }

  /// ✅ **التحقق مما إذا كان المستخدم مسجّل الدخول**
  Future<bool> isLoggedIn() async {
    final session = Supabase.instance.client.auth.currentSession;
    return session != null;
  }

  /// ✅ **جلب `userId`**
  Future<String?> getUserId() async {
    final user = Supabase.instance.client.auth.currentUser;
    return user?.id;
  }

  /// ✅ **مراقبة تغييرات الأطباء المفضلين في Firestore**
  StreamSubscription? _favoritesSubscription;

  void listenToFavoriteDoctors(String userId) {
    _favoritesSubscription?.cancel(); // إلغاء الاشتراك القديم قبل إنشاء اشتراك جديد

    _favoritesSubscription = Supabase.instance.client
        .from('users')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .listen((users) async {
      if (users.isEmpty || !(users[0] as Map).containsKey('favorites')) {
        _favoriteDoctorsController.add([]);
        return;
      }

      final userDoc = users[0];


      List<String> favoriteIds = List<String>.from(userDoc['favorites'] ?? []);
      List<Map<String, dynamic>> doctors = [];

      for (String doctorId in favoriteIds) {
        final response = await Supabase.instance.client
            .from('doctors')
            .select()
            .eq('id', doctorId)
            .maybeSingle();

        if (response != null) {
          final Map<String, dynamic> doctorData = response;


          // ✅ تعيين `defaultImage` حسب الجنس واللقب
          String gender = (doctorData['gender'] ?? "male").toLowerCase();
          String title = (doctorData['title'] ?? "").toLowerCase();
          String defaultImage = (title == "dr.")
              ? (gender == "female" ? "assets/images/female-doc.png" : "assets/images/male-doc.png")
              : (gender == "female" ? "assets/images/female-phys.png" : "assets/images/male-phys.png");

          // ✅ التأكد من أن `doctorImage` ليس فارغًا
          String doctorImage = doctorData['doctor_image'] != null && doctorData['doctor_image'].isNotEmpty
              ? doctorData['doctor_image']
              : defaultImage;

          // ✅ التأكد من أن `lastUpdated` هو رقم `int`
          int lastUpdated = doctorData['lastUpdated'] != null
              ? DateTime.tryParse(doctorData['lastUpdated'] ?? '')?.millisecondsSinceEpoch ?? 0
              : 0;

          doctors.add({
            'id': doctorId,
            'title': doctorData['title'] ?? "",
            'first_name': doctorData['firstName'] ?? "",
            'last_name': doctorData['lastName'] ?? "",
            'specialty': doctorData['specialty'] ?? "",
            'doctor_image': doctorImage,
            'gender': gender,
            'clinic': doctorData['clinic'] ?? "",
            'phone_number': doctorData['phone_number'] ?? "",
            'email': doctorData['email'] ?? "",
            'profile_description': doctorData['profile_description'] ?? "",
            'specialties': doctorData['specialties'] ?? [],
            'website': doctorData['website'] ?? "",
            'address': doctorData['address'] ?? {},
            'opening_hours': doctorData['opening_hours'] ?? {},
            'languages': doctorData['languages'] ?? [],
            'last_updated': lastUpdated,
          });
        }
      }

      await saveData('favoriteDoctors', doctors);
      _favoriteDoctorsController.add(doctors); // تحديث الـ Stream
    });
  }

  /// ✅ **إيقاف الاستماع إلى التغييرات**
  void cancelFavoriteDoctorsListener() {
    _favoritesSubscription?.cancel();
    _favoritesSubscription = null;
  }

  /// ✅ **الاستماع إلى تغييرات المواعيد**
  StreamSubscription? _appointmentsSubscription;

  void listenToAppointments(String userId) {
    _appointmentsSubscription?.cancel();

    _appointmentsSubscription = Supabase.instance.client
        .from('appointments')
        .stream(primaryKey: ['id'])
        .eq('userId', userId)
        .listen((appointmentsData) async {
      List<Map<String, dynamic>> upcoming = [];
      List<Map<String, dynamic>> past = [];
      DateTime now = DocSeraTime.nowSyria();

      for (var appointment in appointmentsData) {
        appointment = Map<String, dynamic>.from(appointment);


        if (appointment['timestamp'] is String) {
          appointment['timestamp'] = appointment['timestamp'];
        }

        if (appointment.containsKey('bookingTimestamp') && appointment['bookingTimestamp'] is String) {
          appointment['bookingTimestamp'] = appointment['bookingTimestamp'];
        }

        DateTime appointmentDate = DocSeraTime.tryParseToSyria(appointment['timestamp'].toString()) ?? DocSeraTime.nowSyria();
        if (appointmentDate.isAfter(now)) {
          upcoming.add(appointment);
        } else {
          past.add(appointment);
        }
      }

      await saveData('upcomingAppointments', upcoming);
      await saveData('pastAppointments', past);

      _appointmentsController.add({'upcoming': upcoming, 'past': past});
    });
  }

  void cancelAppointmentsListener() {
    _appointmentsSubscription?.cancel();
    _appointmentsSubscription = null;
  }

  /// ✅ **Listen to user profile changes and broadcast updates**
  void listenToUserProfile(BuildContext context,String userId, UserCubit userCubit) {
    Supabase.instance.client
        .from('users')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .listen((users) async {
      if (users.isNotEmpty) {
        Map<String, dynamic> userData = users.first;

        SharedPreferences prefs = await SharedPreferences.getInstance();

        // ✅ Read existing cached values
        String currentEmail = prefs.getString('userEmail') ?? '';
        String currentPhone = prefs.getString('userPhone') ?? '';
        bool currentPhoneVerified = prefs.getBool('isPhoneVerified') ?? false;
        bool currentEmailVerified = prefs.getBool('isEmailVerified') ?? false;

        // ✅ Read Firestore values
        String newEmail = userData['email'] ?? 'Not provided';
        String newPhone = userData['phone_number'] ?? 'Not provided';
        bool newPhoneVerified = userData['phoneVerified'] ?? false;
        bool newEmailVerified = userData['emailVerified'] ?? false;

        // ✅ Only trigger update if data **actually** changed
        if (newEmail != currentEmail ||
            newPhone != currentPhone ||
            newPhoneVerified != currentPhoneVerified ||
            newEmailVerified != currentEmailVerified) {

          debugPrint("🔄 Firestore listener detected real change! Updating UI...");

          // ✅ Save updated values in SharedPreferences
          await prefs.setString('userEmail', newEmail);
          await prefs.setString('userPhone', newPhone);
          await prefs.setBool('isPhoneVerified', newPhoneVerified);
          await prefs.setBool('isEmailVerified', newEmailVerified);

          // ✅ Trigger UI Update via UserCubit
          userCubit.loadUserData(context: context);
        } else {
          debugPrint("🔹 Firestore listener detected NO actual changes, ignoring.");
        }
      }
    });
  }





  /// ✅ **Cancel user profile listener if needed**
  void cancelUserProfileListener() {
    _userProfileController.close();
  }

}
