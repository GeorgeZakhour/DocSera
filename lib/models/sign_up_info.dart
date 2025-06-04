class SignUpInfo {
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
  bool termsAccepted = false;
  bool marketingChecked = false;
  String? address;

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
  });
}
