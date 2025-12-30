import 'package:equatable/equatable.dart';

enum AccountSecurityTarget { phone, email }

abstract class AccountSecurityState extends Equatable {
  const AccountSecurityState();

  @override
  List<Object?> get props => [];
}

class AccountSecurityIdle extends AccountSecurityState {
  const AccountSecurityIdle();
}

class AccountSecurityLoading extends AccountSecurityState {
  const AccountSecurityLoading();
}

class AccountSecurityError extends AccountSecurityState {
  final String message;
  const AccountSecurityError(this.message);

  @override
  List<Object?> get props => [message];
}

/// تم إرسال OTP إلى قيمة الهدف (phone/email)
class AccountOtpSent extends AccountSecurityState {
  final AccountSecurityTarget target;
  final String value; // phone or email
  final String otp;   // 👈 جديد

  const AccountOtpSent({
    required this.target,
    required this.value,
    required this.otp,
  });

  @override
  List<Object?> get props => [target, value, otp];
}


class AccountSecurityVerifyingOtp extends AccountSecurityState {}

/// تم التحقق من OTP بنجاح
class AccountOtpVerified extends AccountSecurityState {
  final AccountSecurityTarget target;
  final String value;
  const AccountOtpVerified({required this.target, required this.value});

  @override
  List<Object?> get props => [target, value];
}

/// نجاح تغيير كلمة السر (اختياري لكنه عملي للـ UI)
class AccountPasswordChanged extends AccountSecurityState {
  const AccountPasswordChanged();
}

class AccountPasswordInvalid extends AccountSecurityState {
  const AccountPasswordInvalid();
}


/// 🔐 تحديث إعدادات الأمان (مثل 2FA)
class AccountSecurityUpdating extends AccountSecurityState {
  const AccountSecurityUpdating();
}

class AccountTwoFactorUpdated extends AccountSecurityState {
  final bool enabled;
  const AccountTwoFactorUpdated(this.enabled);

  @override
  List<Object?> get props => [enabled];
}

/// ------------------------------
/// Face ID / Biometric
/// ------------------------------

class AccountBiometricChecking extends AccountSecurityState {
  const AccountBiometricChecking();
}

class AccountBiometricUpdated extends AccountSecurityState {
  final bool enabled;
  final String biometricType;

  const AccountBiometricUpdated({
    required this.enabled,
    required this.biometricType,
  });

  @override
  List<Object?> get props => [enabled, biometricType];
}


class AccountBiometricState extends AccountSecurityState {
  final bool enabled;

  const AccountBiometricState(this.enabled);

  @override
  List<Object?> get props => [enabled];
}
