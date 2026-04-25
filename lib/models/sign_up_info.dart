enum AuthMethod {
  phoneOtp,
  emailPassword,
}

class SignUpInfo {
  AuthMethod authMethod = AuthMethod.phoneOtp;
  String? email;
  String? fakeEmail;    // ✅ الإيميل المزيف المستخدم لـ FirebaseAuth
  String? phoneNumber;
  bool emailVerified = false;
  bool phoneVerified = false;
  String? firstName;
  String? lastName;
  String? dateOfBirth;
  String? gender;
  String? password;
  String? otpCode; // ✅ الرمز السري المستخدم للتحقق في Path A (Phone OTP)
  bool termsAccepted = false;
  bool marketingChecked = false;
  String? address;
  String? referralCode;

  /// هل هذا المستخدم قادم من التطبيق الآخر؟ (DocSera Pro للأطباء)
  bool isCrossApp;

  SignUpInfo({
    this.email,
    this.fakeEmail,
    this.phoneNumber,
    this.firstName,
    this.lastName,
    this.dateOfBirth,
    this.gender,
    this.password,
    this.termsAccepted = false,
    this.marketingChecked = false,
    this.address,
    this.isCrossApp = false,
    this.referralCode,
  });
}
