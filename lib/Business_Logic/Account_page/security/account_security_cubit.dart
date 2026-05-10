import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:docsera/services/biometrics/biometric_storage.dart';
import 'package:docsera/services/supabase/user/account_security_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'account_security_state.dart';

class AccountSecurityCubit extends Cubit<AccountSecurityState> {
  final AccountSecurityService _service;

  AccountSecurityCubit({required AccountSecurityService service})
      : _service = service,
        super(const AccountBiometricState(false)) {
    loadBiometricState();
  }


  final LocalAuthentication _localAuth = LocalAuthentication();

  // ---------------------------------------------------------------------------
  // 🔐 Load biometric state from local storage
  // ---------------------------------------------------------------------------
  Future<void> loadBiometricState() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('enableFaceID') ?? false;

    emit(AccountBiometricState(enabled));
  }


  // ---------------------------------------------------------------------------
  // Availability checks
  // ---------------------------------------------------------------------------

  Future<bool> checkPhoneAvailability(String e164) async {
    try {
      return await _service.isPhoneAvailable(e164);
    } catch (_) {
      return false;
    }
  }


  Future<bool> checkEmailAvailability(String email) async {
    try {
      return await _service.isEmailAvailable(email);
    } catch (e) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Phone OTP flow
  // ---------------------------------------------------------------------------

  Future<void> requestPhoneOtp(String e164) async {
    try {
      emit(const AccountSecurityLoading());
      // The unified send_sms_otp edge function does not return the OTP
      // (it's hashed server-side). Pass null and let the UI prompt the
      // user to enter the code they receive via SMS — same behavior as
      // the rest of the cross-app phone flows.
      await _service.requestPhoneChange(e164);
      emit(AccountOtpSent(
        target: AccountSecurityTarget.phone,
        value: e164,
        otp: null,
      ));
    } catch (e) {
      emit(const AccountSecurityError('OTP_REQUEST_FAILED'));
    }
  }




  Future<void> verifyPhoneOtp(String e164, String otp) async {
    try {
      emit(const AccountSecurityLoading());
      await _service.verifyPhoneOtp(e164, otp);
      emit(AccountOtpVerified(target: AccountSecurityTarget.phone, value: e164));
    } catch (e) {
      emit(const AccountSecurityError('INVALID_OTP'));
    }
  }

  void reset() => emit(const AccountSecurityIdle());


  // ---------------------------------------------------------------------------
  // Email OTP flow
  // ---------------------------------------------------------------------------

  Future<void> requestEmailOtp(String email) async {
    try {
      emit(const AccountSecurityLoading());

      // No OTP returned for email (Edge Function)
      await _service.requestEmailChange(email);

      emit(AccountOtpSent(
        target: AccountSecurityTarget.email,
        value: email,
        otp: null, // No OTP for email
      ));
    } catch (e) {
      emit(const AccountSecurityError('OTP_REQUEST_FAILED'));
    }
  }

  Future<void> verifyEmailOtp(String email, String otp) async {
    try {
      emit(const AccountSecurityLoading());
      // 1. Verify
      await _service.verifyEmailOtp(email, otp);
      
      // 2. Update user (only if verified)
      await _service.updateEmail(email);
      
      emit(AccountOtpVerified(target: AccountSecurityTarget.email, value: email));
    } catch (e) {
      emit(const AccountSecurityError('UNKNOWN_ERROR'));
    }
  }

  // ---------------------------------------------------------------------------
  // Change password
  // ---------------------------------------------------------------------------

  Future<void> changePassword({
    required String current,
    required String next,
    bool signOutOtherDevices = false,
    String? currentDeviceId,
  }) async {
    try {
      emit(const AccountSecurityLoading());
      await _service.changePassword(
        current: current,
        next: next,
        signOutOtherDevices: signOutOtherDevices,
        currentDeviceId: currentDeviceId,
      );
      emit(const AccountPasswordChanged());
      emit(const AccountSecurityIdle());
    } catch (e) {
      if (e.toString().toLowerCase().contains('invalid login')) {
        emit(const AccountPasswordInvalid());
      } else {
        emit(const AccountSecurityError('PASSWORD_CHANGE_FAILED'));
      }
    }
  }




  // ---------------------------------------------------------------------------
// Two Factor Authentication (2FA)
// ---------------------------------------------------------------------------

  Future<void> toggleTwoFactor({
    required bool enable,
  }) async {
    try {
      emit(const AccountSecurityUpdating());

      await _service.updateMySecurity({
        'two_factor_auth_enabled': enable,
      });

      emit(AccountTwoFactorUpdated(enable));
      emit(const AccountSecurityIdle());
    } catch (e) {
      emit(const AccountSecurityError('TWO_FACTOR_UPDATE_FAILED'));
    }
  }



  // ---------------------------------------------------------------------------
// Biometric (Face ID / Fingerprint)
// ---------------------------------------------------------------------------

  Future<void> toggleBiometric({
    required bool enable,
  }) async {
    try {
      emit(const AccountBiometricChecking());

      final available = await _localAuth.getAvailableBiometrics();
      if (available.isEmpty) {
        throw Exception('NO_BIOMETRIC_AVAILABLE');
      }

      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate to change biometric settings',
        options: const AuthenticationOptions(
          biometricOnly: true,
          useErrorDialogs: true,
          stickyAuth: true,
        ),
      );

      if (!authenticated) {
        throw Exception('BIOMETRIC_AUTH_FAILED');
      }

      // 🧠 Detect type
      String biometricType;
      if (Platform.isIOS) {
        biometricType = available.contains(BiometricType.face)
            ? 'face'
            : 'fingerprint';
      } else {
        biometricType = available.contains(BiometricType.strong)
            ? 'fingerprint'
            : 'face';
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('enableFaceID', enable);
      await prefs.setString('biometricType', biometricType);

      // ✅ Fix: If enabling, ensure credentials are mirrored into the secure
      // store. We never read plaintext password from SharedPreferences anymore
      // (it shouldn't be there for new installs). For legacy installs, the
      // migration is handled inside BiometricStorage.getCredentials() itself.
      if (enable) {
        final creds = await BiometricStorage.getCredentials();
        if (creds == null) {
          // No credentials available — biometric will be useless until the
          // user logs in once with their password to populate the store.
          debugPrint('⚠️ Biometric enabled but no credentials in secure store yet');
        }
      }

      // 🔴 إذا تم التعطيل → امسح البيانات
      if (!enable) {
        await BiometricStorage.clearCredentials();
      }

      emit(AccountBiometricUpdated(
        enabled: enable,
        biometricType: biometricType,
      ));

      emit(AccountBiometricState(enable));
    } catch (e) {
      emit(AccountSecurityError(e.toString()));
    }
  }

}
