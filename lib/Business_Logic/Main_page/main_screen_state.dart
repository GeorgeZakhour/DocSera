import 'package:equatable/equatable.dart';

/// ✅ **الحالة الأساسية لجميع حالات `MainScreen`**
abstract class MainScreenState extends Equatable {
  @override
  List<Object?> get props => [];
}

/// ✅ **حالة التحميل الأولي (Shimmer)**
class MainScreenLoading extends MainScreenState {}

/// ✅ **حالة المعالجة بعد تحميل البيانات ولكن قبل عرض الصفحة بالكامل**
class MainScreenProcessing extends MainScreenState {
  final bool isLoggedIn;
  final List<Map<String, dynamic>> favoriteDoctors;

  MainScreenProcessing({required this.isLoggedIn, required this.favoriteDoctors});

  @override
  List<Object?> get props => [isLoggedIn, favoriteDoctors];
}


/// ✅ **حالة التحميل النهائي للصفحة بالكامل**
class MainScreenLoaded extends MainScreenState {
  final bool isLoggedIn;
  final List<Map<String, dynamic>> favoriteDoctors;

  MainScreenLoaded({required this.isLoggedIn, required this.favoriteDoctors});

  @override
  List<Object?> get props => [isLoggedIn, favoriteDoctors];
}

/// ❌ **حالة الخطأ أثناء تحميل الصفحة**
class MainScreenError extends MainScreenState {
  final String message;

  MainScreenError(this.message);

  @override
  List<Object?> get props => [message];
}
