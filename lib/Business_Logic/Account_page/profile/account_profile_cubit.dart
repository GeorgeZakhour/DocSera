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

      DateTime? healthProfileCompletedAt;
      try {
        final completedRes = await _supabase
            .from('users')
            .select('health_profile_completed_at')
            .eq('id', user.id)
            .maybeSingle();
        final raw = completedRes?['health_profile_completed_at'] as String?;
        if (raw != null) healthProfileCompletedAt = DateTime.parse(raw);
      } catch (_) {
        // Non-fatal: banner just shows for this load if the query fails.
      }

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
          healthProfileCompletedAt: healthProfileCompletedAt,
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

      // ✅ Sync name changes to conversations table
      final newFirst = firstName ?? currentState.firstName;
      final newLast = lastName ?? currentState.lastName;
      final fullName = '$newFirst $newLast'.trim();
      final userId = currentState.userId;

      if (firstName != null || lastName != null) {
        // Update patient_name where this user is the patient (direct conversations)
        await _supabase
            .from('conversations')
            .update({'patient_name': fullName})
            .eq('patient_id', userId)
            .filter('relative_id', 'is', null);

        // Update account_holder_name where this user is the account holder
        await _supabase
            .from('conversations')
            .update({'account_holder_name': fullName})
            .eq('patient_id', userId);
      }

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
