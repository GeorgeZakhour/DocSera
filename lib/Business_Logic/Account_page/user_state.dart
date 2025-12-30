import 'package:equatable/equatable.dart';

/// ✅ Base class for all user states
abstract class UserState extends Equatable {
  @override
  List<Object?> get props => [];
}

/// 🔴 User is NOT logged in
class NotLogged extends UserState {}

/// 🔄 User authentication is in progress
class UserLoading extends UserState {}

/// ✅ User is fully loaded with all profile details + points
class UserLoaded extends UserState {
  final String userId;
  final String userName;
  final String userEmail;
  final String userPhone;
  final bool isPhoneVerified;
  final bool isEmailVerified;
  final bool is2FAEnabled;
  final int userPoints;

  // 🔹 ADD THESE
  final String? gender;
  final String? dateOfBirth;
  final Map<String, dynamic>? address;

  UserLoaded({
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.userPhone,
    required this.isPhoneVerified,
    required this.isEmailVerified,
    required this.is2FAEnabled,
    required this.userPoints,

    // 🔹
    this.gender,
    this.dateOfBirth,
    this.address,
  });

  @override
  List<Object?> get props => [
    userId,
    userName,
    userEmail,
    userPhone,
    isPhoneVerified,
    isEmailVerified,
    is2FAEnabled,
    userPoints,
    gender,
    dateOfBirth,
    address,
  ];

  UserLoaded copyWith({
    String? userId,
    String? userName,
    String? userEmail,
    String? userPhone,
    bool? isPhoneVerified,
    bool? isEmailVerified,
    bool? is2FAEnabled,
    int? userPoints,
    String? gender,
    String? dateOfBirth,
    Map<String, dynamic>? address,
  }) {
    return UserLoaded(
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      userPhone: userPhone ?? this.userPhone,
      isPhoneVerified: isPhoneVerified ?? this.isPhoneVerified,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      is2FAEnabled: is2FAEnabled ?? this.is2FAEnabled,
      userPoints: userPoints ?? this.userPoints,
      gender: gender ?? this.gender,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      address: address ?? this.address,
    );
  }
}

/// ❌ Error occurred during authentication or fetching user data
class UserError extends UserState {
  final String message;

  UserError(this.message);

  @override
  List<Object?> get props => [message];
}

class AccountDeactivated extends UserState {
    AccountDeactivated();
}

