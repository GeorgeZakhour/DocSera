import 'package:equatable/equatable.dart';

abstract class AccountProfileState extends Equatable {
  const AccountProfileState();

  @override
  List<Object?> get props => [];
}

/// 🔄 تحميل البيانات
class AccountProfileLoading extends AccountProfileState {}

/// ✅ تم تحميل بيانات الحساب
class AccountProfileLoaded extends AccountProfileState {
  final String userId;

  final String firstName;
  final String lastName;
  final String fullName;

  final String phone;
  final bool isPhoneVerified;

  final String email;
  final bool isEmailVerified;

  final String? gender;
  final String? dateOfBirth;
  final Map<String, dynamic>? address;
  final DateTime? healthProfileCompletedAt;

  const AccountProfileLoaded({
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.fullName,

    required this.phone,
    required this.isPhoneVerified,

    required this.email,
    required this.isEmailVerified,

    this.gender,
    this.dateOfBirth,
    this.address,
    this.healthProfileCompletedAt,
  });

  @override
  List<Object?> get props => [
    userId,
    firstName,
    lastName,
    fullName,
    phone,
    isPhoneVerified,
    email,
    isEmailVerified,
    gender,
    dateOfBirth,
    address,
    healthProfileCompletedAt,
  ];

  AccountProfileLoaded copyWith({
    String? firstName,
    String? lastName,
    String? phone,
    bool? isPhoneVerified,
    String? email,
    bool? isEmailVerified,
    String? gender,
    String? dateOfBirth,
    Map<String, dynamic>? address,
    DateTime? healthProfileCompletedAt,
  }) {
    final newFirst = firstName ?? this.firstName;
    final newLast = lastName ?? this.lastName;

    return AccountProfileLoaded(
      userId: userId,
      firstName: newFirst,
      lastName: newLast,
      fullName: '$newFirst $newLast'.trim(),

      phone: phone ?? this.phone,
      isPhoneVerified: isPhoneVerified ?? this.isPhoneVerified,

      email: email ?? this.email,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,

      gender: gender ?? this.gender,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      address: address ?? this.address,
      healthProfileCompletedAt:
          healthProfileCompletedAt ?? this.healthProfileCompletedAt,
    );
  }
}

/// ❌ خطأ
class AccountProfileError extends AccountProfileState {
  final String message;

  const AccountProfileError(this.message);

  @override
  List<Object?> get props => [message];
}
