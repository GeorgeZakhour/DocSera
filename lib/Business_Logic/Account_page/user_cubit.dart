import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:docsera/Business_Logic/Authentication/auth_cubit.dart';
import 'package:docsera/Business_Logic/Authentication/auth_state.dart';
import 'package:docsera/services/supabase/supabase_user_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'user_state.dart';

class UserCubit extends Cubit<UserState> {
  final SupabaseUserService _supabaseUserService;
  final SharedPreferences _prefs;
  RealtimeChannel? _userChannel;

  UserCubit(this._supabaseUserService,this._prefs) : super(UserLoading());


  Future<void> loadUserData(BuildContext context, {bool useCache = true}) async {
    final authState = context.read<AuthCubit>().state;
    if (authState is! AuthAuthenticated) {
      emit(NotLogged());
      return;
    }

    final userId = authState.user.id;

    try {
      if (useCache) {
        emit(UserLoaded(
          userId: userId,
          userName: _prefs.getString('userName') ?? "Guest",
          userEmail: _prefs.getString('userEmail')?? '',
          userPhone: _prefs.getString('userPhone') ?? '',
          isPhoneVerified: _prefs.getBool('phoneVerified') ?? false,
          isEmailVerified: _prefs.getBool('isEmailVerified') ?? false,
          is2FAEnabled: false,
        ));
        await Future.delayed(const Duration(milliseconds: 100));
      }

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
        print("🔄 Realtime Update Received for user $userId");

        final userData = await SupabaseUserService().getUserData(userId);
        if (userData != null) {
          _emitUserStateFromMap(userData, userId);
        }
      },
    )
        .subscribe();

  }

  Future<void> _emitUserStateFromMap(Map<String, dynamic> userData, String userId) async {
    final firstName = userData['first_name'] ?? '';
    final lastName = userData['last_name'] ?? '';
    final userName = "$firstName $lastName".trim();
    final userEmail = userData['email'];
    final userPhone = userData['phone_number'] ?? '';
    final isPhoneVerified = userData['phone_verified'] ?? false;
    final isEmailVerified = userData['email_verified'] ?? false;
    final is2FAEnabled = userData['two_factor_auth_enabled'] ?? false;

    await _prefs.setString('userName', userName);
    if (userEmail != null) {
      await _prefs.setString('userEmail', userEmail);
    } else {
      await _prefs.remove('userEmail');
    }
    await _prefs.setString('userPhone', userPhone);
    await _prefs.setBool('phoneVerified', isPhoneVerified);
    await _prefs.setBool('isEmailVerified', isEmailVerified);

    emit(UserLoaded(
      userId: userId,
      userName: userName,
      userEmail: userEmail,
      userPhone: userPhone,
      isPhoneVerified: isPhoneVerified,
      isEmailVerified: isEmailVerified,
      is2FAEnabled: is2FAEnabled,
    ));
  }


  @override
  Future<void> close() {
    _userChannel?.unsubscribe();
    return super.close();
  }

  Future<void> updateUserData(BuildContext context, String field, String newValue, {bool? isVerified}) async {
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
      if (field == 'phoneNumber') await _prefs.setBool('phoneVerified', isVerified ?? false);
      if (field == 'email') await _prefs.setBool('isEmailVerified', isVerified ?? false);

      // emit((state).copyWith(
      //   userPhone: field == 'phoneNumber' ? newValue : state.userPhone,
      //   userEmail: field == 'email' ? newValue : state.userEmail,
      //   isPhoneVerified: field == 'phoneNumber' ? isVerified ?? false : state.isPhoneVerified,
      //   isEmailVerified: field == 'email' ? isVerified ?? false : state.isEmailVerified,
      // ));

      await loadUserData(context, useCache: false);

    } catch (e) {
      emit(UserError("Failed to update $field: $e"));
    }
  }

  Future<void> updateUserPhone(BuildContext context, String phone, {required bool isVerified}) async {
    await updateUserData(context, 'phoneNumber', phone, isVerified: isVerified);
  }


  Future<void> logout() async {
    try {
      bool wasFaceIdEnabled = _prefs.getBool('enableFaceID') ?? false;
      String? biometricType = _prefs.getString('biometricType');
      String? savedPhone = _prefs.getString('userPhone');
      String? savedPassword = _prefs.getString('userPassword');

      await _prefs.clear();

      await _prefs.setBool('enableFaceID', wasFaceIdEnabled);
      if (biometricType != null) {
        await _prefs.setString('biometricType', biometricType);
      }
      if (savedPhone != null && savedPassword != null) {
        await _prefs.setString('userPhone', savedPhone);
        await _prefs.setString('userPassword', savedPassword);
      }

      emit(NotLogged());
    } catch (e) {
      emit(UserError("Failed to log out: $e"));
    }
  }
}
