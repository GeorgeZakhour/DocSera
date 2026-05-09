import 'dart:async';
import 'package:docsera/Business_Logic/Authentication/auth_cubit.dart';
import 'package:docsera/Business_Logic/Authentication/auth_state.dart';
import 'package:docsera/services/notifications/notification_service.dart';
import 'package:docsera/services/supabase/user/supabase_user_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'user_state.dart';

class UserCubit extends Cubit<UserState> {
  final SupabaseUserService _supabaseUserService;
  final SharedPreferences _prefs;
  RealtimeChannel? _userChannel;

  UserCubit(this._supabaseUserService, this._prefs) : super(UserLoading());

  // ---------------------------------------------------------------------------
  // 🚀 Load User Data (cache first, then realtime)
  // ---------------------------------------------------------------------------
  Future<void> loadUserData({BuildContext? context, String? explicitUserId, bool useCache = true}) async {
    String userId;

    if (explicitUserId != null) {
      userId = explicitUserId;
    } else if (context != null) {
      final authState = context.read<AuthCubit>().state;
      if (authState is! AuthAuthenticated) {
        emit(NotLogged());
        return;
      }
      userId = authState.user.id;
    } else {
      emit(UserError("No context or userId provided"));
      return;
    }

    try {
      // ----- Load Cached Data First -----
      if (useCache) {
        emit(UserLoaded(
          userId: userId,
          userName: _prefs.getString('userName') ?? "Guest",
          userEmail: _prefs.getString('userEmail') ?? '',
          userPhone: _prefs.getString('userPhone') ?? '',
          isPhoneVerified: _prefs.getBool('phoneVerified') ?? false,
          isEmailVerified: _prefs.getBool('isEmailVerified') ?? false,
          is2FAEnabled: false,
          userPoints: _prefs.getInt('userPoints') ?? 0,
        ));

        await Future.delayed(const Duration(milliseconds: 100));
      }

      // ----- Fetch from Supabase -----
      final userData = await _supabaseUserService.getUserData(userId);
      if (userData == null) {
        emit(UserError("User data not found"));
        return;
      }

      await _emitUserStateFromMap(userData, userId);
    } catch (e) {
      emit(UserError("Failed to load user data: $e"));
    }
  }

  // ---------------------------------------------------------------------------
  // 🔄 Realtime Listener for User Row
  // ---------------------------------------------------------------------------
  void startRealtimeUserListener(String userId) {
    _userChannel?.unsubscribe();

    _userChannel = Supabase.instance.client
        .channel('public:users')
        .onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'users',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'id',
        value: userId,
      ),
      callback: (payload) async {
        debugPrint("🔄 Realtime Update Received for user $userId");

        final userData = await Supabase.instance.client.rpc('rpc_get_my_user');
        if (userData != null) {
          _emitUserStateFromMap(userData, userId);
        }
      },
    ).subscribe();
  }

  // ---------------------------------------------------------------------------
  // 🔁 Convert Map → UserLoaded + Save to Cache
  // ---------------------------------------------------------------------------
  Future<void> _emitUserStateFromMap(
      Map<String, dynamic> userData,
      String userId,
      ) async {
    final bool isActive = userData['is_active'] == true;

    final firstName = userData['first_name']?.toString() ?? '';
    final lastName  = userData['last_name']?.toString() ?? '';
    final userName  = "$firstName $lastName".trim();

    final userEmail = (userData['email']?.toString() ?? '').trim();
    final userPhone = (userData['phone_number']?.toString() ?? '').trim();

    final isPhoneVerified = userData['phone_verified'] == true;
    final isEmailVerified = userData['email_verified'] == true;
    final is2FAEnabled    = userData['two_factor_auth_enabled'] == true;

    final int userPoints = userData['points'] ?? 0;

    // 🟢 NEW FIELDS
    final String? gender = userData['gender'];
    final String? dateOfBirth = userData['date_of_birth'];
    final Map<String, dynamic>? address =
    (userData['address'] as Map?)?.cast<String, dynamic>();

    if (!isActive) {
      // 🚫 الحساب معطّل (Soft deleted)

      // 1️⃣ أوقف أي realtime listener
      await _userChannel?.unsubscribe();

      // 2️⃣ Drop this device's user_devices row first so notifications
      //    for the just-deactivated account stop firing here, then sign
      //    out of Supabase Auth.
      try { await NotificationService.instance.deleteToken(); } catch (_) {}
      await Supabase.instance.client.auth.signOut();

      // 3️⃣ نظّف الكاش (مع الحفاظ على FaceID إذا أردت)
      final wasFaceIdEnabled = _prefs.getBool('enableFaceID') ?? false;
      final biometricType = _prefs.getString('biometricType');

      await _prefs.clear();

      if (wasFaceIdEnabled) {
        await _prefs.setBool('enableFaceID', true);
      }
      if (biometricType != null) {
        await _prefs.setString('biometricType', biometricType);
      }

      // 4️⃣ Emit حالة خاصة
      emit(AccountDeactivated());

      return; // ⛔ لا تكمل
    }


    // ----- Cache -----
    await _prefs.setString('userName', userName);
    await _prefs.setString('userEmail', userEmail);
    await _prefs.setString('userPhone', userPhone);
    await _prefs.setBool('phoneVerified', isPhoneVerified);
    await _prefs.setBool('isEmailVerified', isEmailVerified);
    await _prefs.setInt('userPoints', userPoints);

    emit(
      UserLoaded(
        userId: userId,
        userName: userName,
        userEmail: userEmail,
        userPhone: userPhone,
        isPhoneVerified: isPhoneVerified,
        isEmailVerified: isEmailVerified,
        is2FAEnabled: is2FAEnabled,
        userPoints: userPoints,

        // 🟢 PASS THEM HERE
        gender: gender,
        dateOfBirth: dateOfBirth,
        address: address,
      ),
    );
  }


  // ---------------------------------------------------------------------------
  // 📴 Dispose
  // ---------------------------------------------------------------------------
  @override
  Future<void> close() {
    _userChannel?.unsubscribe();
    return super.close();
  }

  // ---------------------------------------------------------------------------
  // ✏️ Update User Data (email/phone)
  // ---------------------------------------------------------------------------
  Future<void> updateUserData(
      BuildContext context, String field, String newValue,
      {bool? isVerified}) async {
    try {
      final state = this.state;
      if (state is! UserLoaded) return;

      final userId = state.userId;

      final updateData = <String, dynamic>{};
      if (field == 'phoneNumber') {
        updateData['phone_number'] = newValue;
        updateData['phone_verified'] = isVerified;
      } else if (field == 'email') {
        updateData['email'] = newValue;
        updateData['email_verified'] = isVerified;
      }

      await _supabaseUserService.updateUser(userId, updateData);

      await _prefs.setString(field, newValue);
      if (field == 'phoneNumber') {
        await _prefs.setBool('phoneVerified', isVerified ?? false);
      }
      if (field == 'email') {
        await _prefs.setBool('isEmailVerified', isVerified ?? false);
      }

      // Reload full profile after update
      await loadUserData(context: context, useCache: false);
    } catch (e) {
      emit(UserError("Failed to update $field: $e"));
    }
  }

  Future<void> updateUserPhone(BuildContext context, String phone,
      {required bool isVerified}) async {
    await updateUserData(context, 'phoneNumber', phone, isVerified: isVerified);
  }

  // ---------------------------------------------------------------------------
  // 🚪 Logout
  // ---------------------------------------------------------------------------
  Future<void> logout() async {
    try {
      bool wasFaceIdEnabled = _prefs.getBool('enableFaceID') ?? false;
      String? biometricType = _prefs.getString('biometricType');

      await _prefs.clear();

      await _prefs.setBool('enableFaceID', wasFaceIdEnabled);
      if (biometricType != null) {
        await _prefs.setString('biometricType', biometricType);
      }

      emit(NotLogged());
    } catch (e) {
      emit(UserError("Failed to log out: $e"));
    }
  }

}
