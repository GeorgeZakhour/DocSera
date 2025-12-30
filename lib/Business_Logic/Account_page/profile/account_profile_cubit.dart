import 'package:docsera/services/supabase/user/account_profile_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'account_profile_state.dart';

class AccountProfileCubit extends Cubit<AccountProfileState> {
  final AccountProfileService _service;
  final SupabaseClient _supabase;

  AccountProfileCubit({
    required AccountProfileService service,
    SupabaseClient? supabase,
  })  : _service = service,
        _supabase = supabase ?? Supabase.instance.client,
        super(AccountProfileLoading());

  // ---------------------------------------------------------------------------
  // 🚀 Load My Profile (via rpc_get_my_user)
  // ---------------------------------------------------------------------------
  Future<void> loadProfile() async {
    try {
      emit(AccountProfileLoading());

      final user = _supabase.auth.currentUser;
      if (user == null) {
        emit(const AccountProfileError('Not authenticated'));
        return;
      }

      final data = await _service.getMyUser();
      if (data == null) {
        emit(const AccountProfileError('Profile not found'));
        return;
      }

      final firstName = data['first_name']?.toString() ?? '';
      final lastName  = data['last_name']?.toString() ?? '';

      final phone = data['phone_number']?.toString() ?? '';
      final isPhoneVerified = data['phone_verified'] == true;

      final email = data['email']?.toString() ?? '';
      final isEmailVerified = data['email_verified'] == true;

      emit(
        AccountProfileLoaded(
          userId: user.id,

          firstName: firstName,
          lastName: lastName,
          fullName: '$firstName $lastName'.trim(),

          phone: phone,
          isPhoneVerified: isPhoneVerified,

          email: email,
          isEmailVerified: isEmailVerified,

          gender: data['gender'],
          dateOfBirth: data['date_of_birth'],
          address: (data['address'] as Map?)?.cast<String, dynamic>(),
        ),
      );
    } catch (e) {
      emit(AccountProfileError('Failed to load profile: $e'));
    }
  }

  // ---------------------------------------------------------------------------
  // ✏️ Update Profile (name / gender / dob / address)
  // ---------------------------------------------------------------------------
  Future<void> updateProfile({
    String? firstName,
    String? lastName,
    String? gender,
    String? dateOfBirth,
    Map<String, dynamic>? address,
  }) async {
    try {
      final currentState = state;
      if (currentState is! AccountProfileLoaded) return;

      final payload = <String, dynamic>{};

      if (firstName != null) payload['first_name'] = firstName;
      if (lastName != null) payload['last_name'] = lastName;
      if (gender != null) payload['gender'] = gender;
      if (dateOfBirth != null) payload['date_of_birth'] = dateOfBirth;
      if (address != null) payload['address'] = address;

      if (payload.isEmpty) return;

      await _service.updateMyUser(payload);

      emit(
        currentState.copyWith(
          firstName: firstName,
          lastName: lastName,
          gender: gender,
          dateOfBirth: dateOfBirth,
          address: address,
        ),
      );
    } catch (e) {
      emit(AccountProfileError('Failed to update profile: $e'));
    }
  }
}
