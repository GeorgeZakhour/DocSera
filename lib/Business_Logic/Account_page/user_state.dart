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

  /// ⭐ NEW FIELD: total points for the user
  final int userPoints;

  UserLoaded({
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.userPhone,
    required this.isPhoneVerified,
    required this.isEmailVerified,
    required this.is2FAEnabled,
    required this.userPoints,
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
  ];

  /// 🔁 copyWith (includes userPoints)
  UserLoaded copyWith({
    String? userId,
    String? userName,
    String? userEmail,
    String? userPhone,
    bool? isPhoneVerified,
    bool? isEmailVerified,
    bool? is2FAEnabled,
    int? userPoints,
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
