import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:docsera/Business_Logic/Authentication/auth_cubit.dart';
import 'package:docsera/Business_Logic/Authentication/auth_state.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/firestore/firestore_user_service.dart';
import 'user_state.dart';

class UserCubit extends Cubit<UserState> {
  final FirestoreUserService _firestoreService;
  final SharedPreferences _prefs;
  StreamSubscription<DocumentSnapshot>? _userSubscription;

  UserCubit(this._firestoreService, this._prefs) : super(UserLoading());


  Future<void> loadUserData(BuildContext context, {bool useCache = true}) async {
    final authState = context.read<AuthCubit>().state;
    if (authState is AuthUnauthenticated) {
      emit(NotLogged());
      return;
    }

    if (authState is! AuthAuthenticated) return;
    final userId = authState.user.uid;

    try {
      print("📌 [DEBUG] Loaded userId from AuthCubit: $userId");

      bool isFaceIdEnabled = _prefs.getBool('enableFaceID') ?? false;
      String biometricType = _prefs.getString('biometricType') ?? "Unknown";

      print("🟢 [DEBUG] Face ID Enabled: $isFaceIdEnabled");
      print("🟢 [DEBUG] Biometric Type: $biometricType");

      if (useCache) {
        print("📌 [DEBUG] Cached User Data:");
        print("🔹 userName: ${_prefs.getString('userName')}");
        print("🔹 userEmail: ${_prefs.getString('userEmail')}");
        print("🔹 userPhone: ${_prefs.getString('userPhone')}");
        print("🔹 isPhoneVerified: ${_prefs.getBool('isPhoneVerified')}");
        print("🔹 isEmailVerified: ${_prefs.getBool('isEmailVerified')}");

        emit(UserLoaded(
          userId: userId,
          userName: _prefs.getString('userName') ?? "Guest",
          userEmail: _prefs.getString('userEmail'),
          userFakeEmail: _prefs.getString('userFakeEmail') ?? "Not provided",
          userPhone: _prefs.getString('userPhone') ?? '',
          isPhoneVerified: _prefs.getBool('phoneVerified') ?? false,
          isEmailVerified: _prefs.getBool('isEmailVerified') ?? false,
          is2FAEnabled: false, // لا يوجد بيانات مؤقتة عن 2FA فاجعلها false
        ));


        await Future.delayed(const Duration(milliseconds: 100));
      }

      // ✅ Fetch fresh data from Firestore
      final userData = await _firestoreService.getUserData(userId);
      if (userData == null) {
        emit(UserError("User data not found"));
        return;
      }

      String firstName = userData['firstName'] ?? '';
      String lastName = userData['lastName'] ?? '';
      String userName = "$firstName $lastName".trim();
      String? userEmail = userData['email'];
      String userPhone = userData['phoneNumber'] ?? '';
      bool isPhoneVerified = userData['phoneVerified'] ?? false;
      bool isEmailVerified = userData['emailVerified'] ?? false;

      await _prefs.setString('userName', userName);
      if (userEmail != null) {
        await _prefs.setString('userEmail', userEmail);
      } else {
        await _prefs.remove('userEmail');
      }
      await _prefs.setString('userPhone', userPhone);
      await _prefs.setString('userFakeEmail', userData['fakeEmail'] ?? '');
      await _prefs.setBool('phoneVerified', isPhoneVerified);
      await _prefs.setBool('isEmailVerified', isEmailVerified);

      print("✅ [DEBUG] Firestore Data Updated & Saved in SharedPreferences!");

      emit(UserLoaded(
        userId: userId,
        userName: userName,
        userEmail: userEmail,
        userFakeEmail: userData['fakeEmail'] ?? '',
        userPhone: userPhone,
        isPhoneVerified: isPhoneVerified,
        isEmailVerified: isEmailVerified,
        is2FAEnabled: userData['twoFactorAuthEnabled'] ?? false, // أضف هذا السطر
      ));


    } catch (e) {
      emit(UserError("Failed to load user data: $e"));
    }
  }


  /// **🔹 Updating User Data (Ensuring Instant UI Update)**
  Future<void> updateUserData(String field, String newValue, {bool? isVerified}) async {
    try {
      final state = this.state;
      if (state is! UserLoaded) return;

      // ✅ Update UI **immediately**
      final updatedState = UserLoaded(
        userId: state.userId,
        userName: state.userName,
        userEmail: field == 'email' ? newValue : state.userEmail,
        userFakeEmail: state.userFakeEmail,
        userPhone: field == 'phoneNumber' ? newValue : state.userPhone,
        isPhoneVerified: field == 'phoneNumber' ? isVerified ?? state.isPhoneVerified : state.isPhoneVerified,
        isEmailVerified: field == 'email' ? isVerified ?? state.isEmailVerified : state.isEmailVerified,
        is2FAEnabled: (state as UserLoaded).is2FAEnabled, // ✅ أضف هذا السطر
      );


      emit(updatedState);

      // ✅ Then update Firestore
      Map<String, dynamic> updateData = {field: newValue};
      if (field == 'phoneNumber') updateData['phoneVerified'] = isVerified ?? state.isPhoneVerified;
      if (field == 'email') updateData['emailVerified'] = isVerified ?? state.isEmailVerified;

      await _firestoreService.updateUser(state.userId, updateData);

      // ✅ Save to SharedPreferences AFTER UI update
      await _prefs.setString(field, newValue);
      if (field == 'phoneNumber') await _prefs.setBool('phoneVerified', isVerified ?? state.isPhoneVerified);
      if (field == 'email') await _prefs.setBool('isEmailVerified', isVerified ?? state.isEmailVerified);

    } catch (e) {
      emit(UserError("Failed to update $field: $e"));
    }
  }

  Future<void> updateUserPhone(String phone, {required bool isVerified}) async {
    final userId = state is UserLoaded ? (state as UserLoaded).userId : null;
    if (userId == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'phoneNumber': phone,
        'phoneVerified': isVerified,
      });

      emit((state as UserLoaded).copyWith(
        userPhone: phone,
        isPhoneVerified: isVerified,
      ));
    } catch (e) {
      print("❌ Error updating Firestore phone: $e");
    }
  }



  /// **🔥 Real-time Firestore Listener**
  void startListeningToUserChanges() {
    String? userId = _prefs.getString('userId');
    if (userId == null || userId.isEmpty) return;

    _userSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.exists) {
        final data = snapshot.data()!;
        print("🔥 [DEBUG] Firestore listener detected change: $data");

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userName', "${data['firstName'] ?? ''} ${data['lastName'] ?? ''}".trim());
        if (data['email'] != null) {
          await prefs.setString('userEmail', data['email']);
        } else {
          await prefs.remove('userEmail');
        }
        await prefs.setString('userFakeEmail', data['fakeEmail'] ?? 'Not provided');
        if (data['phoneNumber'] != null) {
          await prefs.setString('userPhone', data['phoneNumber']);
        } else {
          await prefs.remove('userPhone');
        }
        await prefs.setBool('phoneVerified', data['phoneVerified'] ?? false);
        await prefs.setBool('isEmailVerified', data['emailVerified'] ?? false);
        bool is2FAEnabled = data['twoFactorAuthEnabled'] ?? false;

        emit(UserLoaded(
          userId: userId,
          userName: prefs.getString('userName')!,
          userEmail: prefs.getString('userEmail'),
          userFakeEmail: prefs.getString('userFakeEmail')!,
          userPhone: prefs.getString('userPhone')!,
          isPhoneVerified: prefs.getBool('phoneVerified')!,
          isEmailVerified: prefs.getBool('isEmailVerified')!,
          is2FAEnabled: is2FAEnabled,
        ));

      }
    });
  }

  @override
  Future<void> close() {
    _userSubscription?.cancel();
    return super.close();
  }

  /// **🔹 Logout (Preserving Face ID Settings)**
  Future<void> logout() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();

      // ✅ Preserve Face ID settings and credentials
      bool wasFaceIdEnabled = prefs.getBool('enableFaceID') ?? false;
      String? biometricType = prefs.getString('biometricType');
      String? savedEmail = prefs.getString('userEmail');
      String? savedPassword = prefs.getString('userPassword');

      print("📌 [DEBUG] Logging out. Preserving Face ID: $wasFaceIdEnabled, Biometric Type: $biometricType");

      await prefs.clear(); // Clears everything

      // ✅ Restore Face ID and credentials
      await prefs.setBool('enableFaceID', wasFaceIdEnabled);
      if (biometricType != null) {
        await prefs.setString('biometricType', biometricType);
      }
      if (savedEmail != null && savedPassword != null) {
        await prefs.setString('userEmail', savedEmail);
        await prefs.setString('userPassword', savedPassword);
      }

      print("✅ [DEBUG] User logged out. Face ID settings retained.");

      emit(NotLogged());
    } catch (e) {
      emit(UserError("Failed to log out: $e"));
    }
  }


}
