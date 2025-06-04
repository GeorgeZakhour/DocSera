import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:docsera/utils/shared_prefs_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FirestoreUserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SharedPrefsService _sharedPrefsService = SharedPrefsService();

  Future<String> generateNextFakeEmail() async {
    final counterRef = FirebaseFirestore.instance.collection('metadata').doc('emailCounter');

    return FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(counterRef);

      int currentNumber = snapshot.data()?['lastFakeEmailNumber'] ?? 0;
      int nextNumber = currentNumber + 1;

      transaction.update(counterRef, {'lastFakeEmailNumber': nextNumber});

      final padded = nextNumber.toString().padLeft(7, '0');
      final fakeEmail = 'user$padded@docsera.com';

      print("📬 Generated from counter: $fakeEmail");

      return fakeEmail;
    });
  }







  Future<bool> isFakeEmailUsedInAuth(String fakeEmail) async {
    try {
      final methods = await FirebaseAuth.instance.fetchSignInMethodsForEmail(fakeEmail);
      return methods.isNotEmpty;
    } catch (e) {
      return false;
    }
  }



  /// ✅ التحقق مما إذا كان رقم الهاتف موجود مسبقًا في Firestore
  Future<bool> isPhoneNumberExists(String phoneNumber) async {
    print("📞 Checking if phone number exists: $phoneNumber");

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('phoneNumber', isEqualTo: phoneNumber)
        .get();
    print("📊 Matching documents found: ${snapshot.docs.length}");

    return snapshot.docs.isNotEmpty;
  }

  /// **إضافة مستخدم إلى Firestore بمعرف محدد**
  Future<void> addUser(String userId, Map<String, dynamic> userData) async {
    try {
      userData['createdAt'] = FieldValue.serverTimestamp();
      userData['updatedAt'] = FieldValue.serverTimestamp();
      await _firestore.collection('users').doc(userId).set(userData);
    } catch (e) {
      throw Exception('Failed to add user: ${e.toString()}');
    }
  }

  /// **جلب بيانات المستخدم حسب معرف المستخدم**
  Future<Map<String, dynamic>?> getUserData(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        return userDoc.data();
      }
      return null;
    } catch (e) {
      throw Exception('Failed to fetch user data: $e');
    }
  }

  /// **جلب مستخدم عن طريق البريد الإلكتروني أو رقم الهاتف**
  Future<DocumentSnapshot<Map<String, dynamic>>> getUserByEmailOrPhone(
      String input) async {
    try {
      final emailQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: input)
          .limit(1)
          .get();

      if (emailQuery.docs.isNotEmpty) {
        return emailQuery.docs.first;
      }

      final phoneQuery = await _firestore
          .collection('users')
          .where('phoneNumber', isEqualTo: input)
          .limit(1)
          .get();

      if (phoneQuery.docs.isNotEmpty) {
        return phoneQuery.docs.first;
      }

      throw Exception('User not found');
    } catch (e) {
      throw Exception('Error retrieving user: $e');
    }
  }

  /// **تحديث بيانات المستخدم في Firestore**
  Future<void> updateUser(String userId, Map<String, dynamic> updatedData) async {
    try {
      updatedData['updatedAt'] = FieldValue.serverTimestamp();
      await _firestore.collection('users').doc(userId).update(updatedData);
    } catch (e) {
      throw Exception('Failed to update user: ${e.toString()}');
    }
  }

  /// **جلب الأطباء المفضلين للمستخدم**
  Future<List<String>> getUserFavorites(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists && userDoc.data()!.containsKey('favorites')) {
        return List<String>.from(userDoc.data()!['favorites'] ?? []);
      }
      return [];
    } catch (e) {
      print("❌ Error fetching favorites: $e");
      return [];
    }
  }

  /// **تحديث قائمة الأطباء المفضلين للمستخدم**
  Future<void> updateUserFavorites(String userId, List<String> favorites) async {
    try {
      await _firestore.collection('users').doc(userId).update({'favorites': favorites});
    } catch (e) {
      print("❌ Error updating favorites: $e");
    }
  }

  /// **التحقق مما إذا كان المستخدم موجودًا بناءً على البريد الإلكتروني أو رقم الهاتف**
  Future<bool> doesUserExist({String? email, String? phoneNumber}) async {
    try {
      if (email != null) {
        final emailQuery = await _firestore
            .collection('users')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();

        if (emailQuery.docs.isNotEmpty) {
          return true;
        }
      }

      if (phoneNumber != null) {
        final phoneQuery = await _firestore
            .collection('users')
            .where('phoneNumber', isEqualTo: phoneNumber)
            .limit(1)
            .get();

        if (phoneQuery.docs.isNotEmpty) {
          return true;
        }
      }

      return false;
    } catch (e) {
      throw Exception('Error checking for duplicates: $e');
    }
  }

  /// **جلب المستخدمين بطريقة مجزأة (Paginated)**
  Future<List<DocumentSnapshot>> getPaginatedUsers(
      {DocumentSnapshot? lastUser, int limit = 10}) async {
    try {
      Query query = _firestore.collection('users').orderBy('createdAt').limit(limit);

      if (lastUser != null) {
        query = query.startAfterDocument(lastUser);
      }

      final querySnapshot = await query.get();
      return querySnapshot.docs;
    } catch (e) {
      throw Exception('Error retrieving paginated users: $e');
    }
  }

  /// ✅ **جلب الأطباء المفضلين**
  Future<List<Map<String, dynamic>>> getFavoriteDoctors(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();

      if (!userDoc.exists || !userDoc.data()!.containsKey('favorites')) {
        return [];
      }

      List<String> favoriteIds = List<String>.from(userDoc.get('favorites') ?? []);
      List<Map<String, dynamic>> doctors = [];

      for (String doctorId in favoriteIds) {
        DocumentSnapshot doctorDoc = await _firestore.collection('doctors').doc(doctorId).get();

        if (doctorDoc.exists) {
          Map<String, dynamic> doctorData = doctorDoc.data() as Map<String, dynamic>;

          // ✅ Fetch `lastUpdated` timestamp as `int`
          int lastUpdated = doctorData['lastUpdated'] != null
              ? (doctorData['lastUpdated'] as Timestamp).millisecondsSinceEpoch
              : 0;

          // ✅ Ensure profile image logic
          String gender = (doctorData['gender'] ?? "male").toLowerCase();
          String title = (doctorData['title'] ?? "").toLowerCase();
          String profileImage = doctorData['profileImage'] ?? "";
          if (profileImage.isEmpty || !profileImage.startsWith("http")) {
            profileImage = (title == "dr.")
                ? (gender == "female" ? 'assets/images/female-doc.png' : 'assets/images/male-doc.png')
                : (gender == "female" ? 'assets/images/female-phys.png' : 'assets/images/male-phys.png');
          }

          // ✅ Store all necessary fields
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
            'lastUpdated': lastUpdated, // ✅ Now storing as an int
          });
        }
      }

      // ✅ Cache results in SharedPreferences
      await _sharedPrefsService.saveData('favoriteDoctors', doctors);
      return doctors;
    } catch (e) {
      print("❌ Error fetching favorite doctors: $e");
      return [];
    }
  }


  /// ✅ **جلب الأطباء المفضلين في الوقت الفعلي باستخدام Firestore Listener** DELETE
  Stream<List<Map<String, dynamic>>> listenToFavoriteDoctors(String userId) {
    return _firestore.collection('users').doc(userId).snapshots().asyncMap((userDoc) async {
      if (!userDoc.exists || !userDoc.data()!.containsKey('favorites')) {
        return [];
      }

      List<String> favoriteIds = List<String>.from(userDoc.get('favorites') ?? []);
      List<Map<String, dynamic>> doctors = [];

      for (String doctorId in favoriteIds) {
        DocumentSnapshot doctorDoc = await _firestore.collection('doctors').doc(doctorId).get();

        if (doctorDoc.exists) {
          Map<String, dynamic> doctorData = doctorDoc.data() as Map<String, dynamic>;

          // ✅ تعيين صورة افتراضية للطبيب
          String gender = (doctorData['gender'] ?? "male").toLowerCase();
          String title = (doctorData['title'] ?? "").toLowerCase();
          String defaultImage = (title == "dr.")
              ? (gender == "female" ? "assets/images/female-doc.png" : "assets/images/male-doc.png")
              : (gender == "female" ? "assets/images/female-phys.png" : "assets/images/male-phys.png");

          String profileImage = doctorData.containsKey('profileImage') && doctorData['profileImage'].isNotEmpty
              ? doctorData['profileImage']
              : defaultImage;

          // ✅ تحويل `lastUpdated` إلى `int`
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

      // ✅ تحديث البيانات في `SharedPreferences`
      await _sharedPrefsService.saveData('favoriteDoctors', doctors);
      return doctors;
    });
  }

  /// ✅ **Load Cached Data**
  Future<List<dynamic>> loadCachedData(String key) async {
    try {
      return await _sharedPrefsService.loadData(key) ?? [];
    } catch (e) {
      print("❌ Error loading cached data ($key): $e");
      return [];
    }
  }

  /// ✅ **Save Cached Data**
  Future<void> saveCachedData(String key, List<Map<String, dynamic>> data) async {
    try {
      await _sharedPrefsService.saveData(key, data);
      print("✅ [$key] Data saved.");
    } catch (e) {
      print("❌ Error saving cached data ($key): $e");
    }
  }


  /// ✅ **جلب المواعيد من Firestore مع استخدام الكاش**
  Future<Map<String, List<Map<String, dynamic>>>> getUserAppointments(String userId) async {
    try {
      // ✅ محاولة تحميل المواعيد من الكاش أولًا
      var cachedUpcoming = await _sharedPrefsService.loadData('upcomingAppointments') ?? [];
      var cachedPast = await _sharedPrefsService.loadData('pastAppointments') ?? [];

      if (cachedUpcoming.isNotEmpty || cachedPast.isNotEmpty) {
        print("⚡ Loaded appointments from cache: ${cachedUpcoming.length} upcoming, ${cachedPast.length} past.");
        return {'upcoming': cachedUpcoming, 'past': cachedPast};
      }

      print("📡 No cache found. Fetching appointments from Firestore...");

      QuerySnapshot querySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('appointments')
          .orderBy('timestamp', descending: false)
          .get();

      List<Map<String, dynamic>> upcoming = [];
      List<Map<String, dynamic>> past = [];
      DateTime now = DateTime.now().toLocal();

      for (var doc in querySnapshot.docs) {
        Map<String, dynamic> appointment = doc.data() as Map<String, dynamic>;

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

      // ✅ حفظ المواعيد في الكاش
      await _sharedPrefsService.saveData('upcomingAppointments', upcoming);
      await _sharedPrefsService.saveData('pastAppointments', past);

      print("✅ Appointments fetched from Firestore and cached.");
      return {'upcoming': upcoming, 'past': past};

    } catch (e) {
      print("❌ Error fetching appointments: $e");
      return {'upcoming': [], 'past': []};
    }
  }

  /// ✅ **الاستماع لتحديثات المواعيد في الوقت الفعلي باستخدام Firestore Listener**
  Stream<List<Map<String, dynamic>>> listenToUserAppointments(String userId) {
    return _firestore.collection('users').doc(userId).collection('appointments').snapshots().asyncMap((querySnapshot) async {
      List<Map<String, dynamic>> upcoming = [];
      List<Map<String, dynamic>> past = [];
      DateTime now = DateTime.now().toLocal();

      for (var doc in querySnapshot.docs) {
        Map<String, dynamic> appointment = doc.data() as Map<String, dynamic>;

        // ✅ تحويل Timestamp إلى String
        if (appointment['timestamp'] is Timestamp) {
          appointment['timestamp'] = (appointment['timestamp'] as Timestamp).toDate().toIso8601String();
        }
        if (appointment.containsKey('bookingTimestamp') && appointment['bookingTimestamp'] is Timestamp) {
          appointment['bookingTimestamp'] = (appointment['bookingTimestamp'] as Timestamp).toDate().toIso8601String();
        }

        // ✅ تصنيف المواعيد (قادمة أو سابقة)
        DateTime appointmentDate = DateTime.parse(appointment['timestamp']);
        if (appointmentDate.isAfter(now)) {
          upcoming.add(appointment);
        } else {
          past.add(appointment);
        }
      }

      // ✅ تحديث الكاش في SharedPreferences
      await _sharedPrefsService.saveData('upcomingAppointments', upcoming);
      await _sharedPrefsService.saveData('pastAppointments', past);

      print("🔥 User appointments updated from Firestore: ${upcoming.length} upcoming, ${past.length} past.");

      return [...upcoming, ...past]; // إرجاع جميع المواعيد
    });
  }

  Future<void> clearAppointmentCache() async {
    await SharedPrefsService().removeData('upcomingAppointments');
    await SharedPrefsService().removeData('pastAppointments');
  }

  StreamSubscription? _appointmentsListener;

  void listenToAppointments(String userId) {
    _appointmentsListener?.cancel(); // ✅ إلغاء أي استماع سابق
    _appointmentsListener = listenToUserAppointments(userId).listen((_) {
      print("🔥 Appointments listener triggered.");
    });
  }

  void cancelAppointmentsListener() {
    _appointmentsListener?.cancel();
    _appointmentsListener = null;
    print("🛑 Appointments listener canceled.");
  }



}