import 'dart:io';

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

      final otp = await _service.requestPhoneChange(e164);

      emit(AccountOtpSent(
        target: AccountSecurityTarget.phone,
        value: e164,
        otp: otp,
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

      final otp = await _service.requestEmailChange(email);

      emit(AccountOtpSent(
        target: AccountSecurityTarget.email,
        value: email,
        otp: otp,
      ));
    } catch (e) {
      emit(const AccountSecurityError('OTP_REQUEST_FAILED'));
    }
  }
  Future<void> verifyEmailOtp(String email, String otp) async {
    try {
      emit(const AccountSecurityLoading());
      await _service.verifyEmailOtp(email, otp);
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
  }) async {
    try {
      emit(const AccountSecurityLoading());
      await _service.changePassword(current: current, next: next);
      emit(const AccountPasswordChanged());
      emit(const AccountSecurityIdle());
    } catch (e) {
      if (e.toString().toLowerCase().contains('invalid login')) {
        emit(const AccountPasswordInvalid());
      } else {
        emit(AccountSecurityError('PASSWORD_CHANGE_FAILED'));
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
