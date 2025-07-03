import 'package:equatable/equatable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// الحالة الأساسية للمصادقة
abstract class AppAuthState extends Equatable {
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AppAuthState {}

class AuthLoading extends AppAuthState {}

class AuthAuthenticated extends AppAuthState {
  final User user;

  AuthAuthenticated(this.user);

  @override
  List<Object?> get props => [user.id];
}

class AuthUnauthenticated extends AppAuthState {}

class AuthError extends AppAuthState {
  final String errorMessage;

  AuthError(this.errorMessage);

  @override
  List<Object?> get props => [errorMessage];
}
