import 'package:equatable/equatable.dart';

/// ✅ **Base class for all user states**
abstract class UserState extends Equatable {
  @override
  List<Object?> get props => [];
}

/// 🔴 **User is NOT logged in**
class NotLogged extends UserState {}

/// 🔄 **User authentication is in progress**
class UserLoading extends UserState {}

/// ✅ **User is fully loaded with all profile details**
class UserLoaded extends UserState {
  final String userId;
  final String userName;
  final String userEmail;
  final String userFakeEmail;
  final String userPhone;
  final bool isPhoneVerified;
  final bool isEmailVerified;

  UserLoaded({
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.userFakeEmail,
    required this.userPhone,
    required this.isPhoneVerified,
    required this.isEmailVerified,
  });

  @override
  List<Object?> get props => [userId, userName, userEmail, userPhone, isPhoneVerified, isEmailVerified];


  UserLoaded copyWith({
    String? userId,
    String? userName,
    String? userEmail,
    String? userFakeEmail,
    String? userPhone,
    bool? isPhoneVerified,
    bool? isEmailVerified,
  }) {
    return UserLoaded(
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      userFakeEmail: userFakeEmail ?? this.userFakeEmail,
      userPhone: userPhone ?? this.userPhone,
      isPhoneVerified: isPhoneVerified ?? this.isPhoneVerified,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
    );
  }

}

/// ❌ **Error occurred during authentication or fetching user data**
class UserError extends UserState {
  final String message;
  UserError(this.message);

  @override
  List<Object?> get props => [message];
}
