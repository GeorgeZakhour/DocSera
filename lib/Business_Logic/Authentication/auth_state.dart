import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// الحالة الأساسية للمصادقة
abstract class AuthState extends Equatable {
  @override
  List<Object?> get props => [];
}

/// الحالة المبدئية (قبل بدء أي عملية)
class AuthInitial extends AuthState {}

/// حالة التحميل (مثلاً عند محاولة تسجيل الدخول أو إنشاء حساب)
class AuthLoading extends AuthState {}

/// المستخدم مسجّل دخول
class AuthAuthenticated extends AuthState {
  final User user;

  AuthAuthenticated(this.user);

  @override
  List<Object?> get props => [user.uid];
}

/// المستخدم غير مسجّل دخول
class AuthUnauthenticated extends AuthState {}

/// حدث خطأ أثناء تسجيل الدخول أو إنشاء حساب
class AuthError extends AuthState {
  final String errorMessage;

  AuthError(this.errorMessage);

  @override
  List<Object?> get props => [errorMessage];
}
