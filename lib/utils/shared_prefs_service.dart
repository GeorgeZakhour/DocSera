import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:docsera/Business_Logic/Account_page/user_cubit.dart';
import 'package:docsera/services/firestore/firestore_user_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';


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
        print("✅ [$key] Boolean flag set to: $data");
      } else {
        print("⚠️ [$key] Invalid boolean value provided: $data");
      }
      return;
    }

    String jsonData = json.encode(data);
    await prefs.setString(key, jsonData);
    print("✅ [$key] Data saved.");
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
      print("⚠️ [$key] No cached data found.");
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
      print("❌ [$key] Error decoding JSON: $e");
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
    final prefs = await _prefs();
    return prefs.getBool('isLoggedIn') ?? false;
  }

  /// ✅ **جلب `userId`**
  Future<String?> getUserId() async {
    final prefs = await _prefs();
    return prefs.getString('userId');
  }

  /// ✅ **مراقبة تغييرات الأطباء المفضلين في Firestore**
  StreamSubscription? _favoritesSubscription;

  void listenToFavoriteDoctors(String userId) {
    _favoritesSubscription?.cancel(); // إلغاء الاشتراك القديم قبل إنشاء اشتراك جديد

    _favoritesSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen((userDoc) async {
      if (!userDoc.exists || !userDoc.data()!.containsKey('favorites')) {
        _favoriteDoctorsController.add([]); // إرسال قائمة فارغة إذا لم يكن هناك بيانات
        return;
      }

      List<String> favoriteIds = List<String>.from(userDoc.get('favorites') ?? []);
      List<Map<String, dynamic>> doctors = [];

      for (String doctorId in favoriteIds) {
        DocumentSnapshot doctorDoc = await FirebaseFirestore.instance.collection('doctors').doc(doctorId).get();
        if (doctorDoc.exists) {
          Map<String, dynamic> doctorData = doctorDoc.data() as Map<String, dynamic>;

          // ✅ تعيين `defaultImage` حسب الجنس واللقب
          String gender = (doctorData['gender'] ?? "male").toLowerCase();
          String title = (doctorData['title'] ?? "").toLowerCase();
          String defaultImage = (title == "dr.")
              ? (gender == "female" ? "assets/images/female-doc.png" : "assets/images/male-doc.png")
              : (gender == "female" ? "assets/images/female-phys.png" : "assets/images/male-phys.png");

          // ✅ التأكد من أن `profileImage` ليس فارغًا
          String profileImage = doctorData['profileImage'] != null && doctorData['profileImage'].isNotEmpty
              ? doctorData['profileImage']
              : defaultImage;

          // ✅ التأكد من أن `lastUpdated` هو رقم `int`
          int lastUpdated = doctorData['lastUpdated'] != null
              ? (doctorData['lastUpdated'] as Timestamp).millisecondsSinceEpoch
              : 0;

          doctors.add({
            'id': doctorId,
            'title': doctorData['title'] ?? "",
            'firstName': doctorData['firstName'] ?? "Unknown",
            'lastName': doctorData['lastName'] ?? "Doctor",
            'specialty': doctorData['specialty'] ?? "Unknown Specialty",
            'profileImage': profileImage,
            'gender': gender,
            'clinic': doctorData['clinic'] ?? "",
            'phoneNumber': doctorData['phoneNumber'] ?? "",
            'email': doctorData['email'] ?? "",
            'profileDescription': doctorData['profileDescription'] ?? "",
            'specialties': doctorData['specialties'] ?? [],
            'website': doctorData['website'] ?? "",
            'address': doctorData['address'] ?? {},
            'openingHours': doctorData['openingHours'] ?? {},
            'languages': doctorData['languages'] ?? [],
            'lastUpdated': lastUpdated,
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

    _appointmentsSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('appointments')
        .snapshots()
        .listen((querySnapshot) async {
      List<Map<String, dynamic>> upcoming = [];
      List<Map<String, dynamic>> past = [];
      DateTime now = DateTime.now().toLocal();

      for (var doc in querySnapshot.docs) {
        Map<String, dynamic> appointment = doc.data();

        if (appointment['timestamp'] is Timestamp) {
          appointment['timestamp'] = (appointment['timestamp'] as Timestamp).toDate().toIso8601String();
        }
        if (appointment.containsKey('bookingTimestamp') && appointment['bookingTimestamp'] is Timestamp) {
          appointment['bookingTimestamp'] = (appointment['bookingTimestamp'] as Timestamp).toDate().toIso8601String();
        }

        DateTime appointmentDate = DateTime.parse(appointment['timestamp']);
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
    FirebaseFirestore.instance.collection('users').doc(userId).snapshots().listen((docSnapshot) async {
      if (docSnapshot.exists) {
        Map<String, dynamic> userData = docSnapshot.data()!;
        SharedPreferences prefs = await SharedPreferences.getInstance();

        // ✅ Read existing cached values
        String currentEmail = prefs.getString('userEmail') ?? '';
        String currentPhone = prefs.getString('userPhone') ?? '';
        bool currentPhoneVerified = prefs.getBool('isPhoneVerified') ?? false;
        bool currentEmailVerified = prefs.getBool('isEmailVerified') ?? false;

        // ✅ Read Firestore values
        String newEmail = userData['email'] ?? 'Not provided';
        String newPhone = userData['phoneNumber'] ?? 'Not provided';
        bool newPhoneVerified = userData['phoneVerified'] ?? false;
        bool newEmailVerified = userData['emailVerified'] ?? false;

        // ✅ Only trigger update if data **actually** changed
        if (newEmail != currentEmail ||
            newPhone != currentPhone ||
            newPhoneVerified != currentPhoneVerified ||
            newEmailVerified != currentEmailVerified) {

          print("🔄 Firestore listener detected real change! Updating UI...");

          // ✅ Save updated values in SharedPreferences
          await prefs.setString('userEmail', newEmail);
          await prefs.setString('userPhone', newPhone);
          await prefs.setBool('isPhoneVerified', newPhoneVerified);
          await prefs.setBool('isEmailVerified', newEmailVerified);

          // ✅ Trigger UI Update via UserCubit
          userCubit.loadUserData(context);
        } else {
          print("🔹 Firestore listener detected NO actual changes, ignoring.");
        }
      }
    });
  }





  /// ✅ **Cancel user profile listener if needed**
  void cancelUserProfileListener() {
    _userProfileController.close();
  }

}
