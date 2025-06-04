// import 'dart:async';
// import 'dart:convert';
// import 'package:bloc/bloc.dart';
// import 'package:docsera/Business_Logic/Main_page/main_screen_state.dart';
// import 'package:docsera/services/firestore/firestore_user_service.dart';
// import 'package:shared_preferences/shared_preferences.dart';
//
// class MainScreenCubit extends Cubit<MainScreenState> {
//   final FirestoreUserService _firestoreService;
//   final SharedPreferences _prefs;
//   StreamSubscription? _favoritesListener;
//   static bool _hasLoadedOnce = false; // ✅ يتم التحقق منه لمنع ظهور `Shimmer` عند التنقل
//
//   MainScreenCubit(this._firestoreService, this._prefs) : super(MainScreenLoading()) {
//     loadMainScreen();
//   }
//
//   Future<void> loadMainScreen() async {
//     try {
//       if (!_hasLoadedOnce) {
//         emit(MainScreenLoading());
//         await Future.delayed(Duration(milliseconds: 100)); // ⬅️ تقليل الزمن لتجنب التأخير
//       }
//
//       bool isLoggedIn = _prefs.getBool('isLoggedIn') ?? false;
//       if (!isLoggedIn) {
//         emit(MainScreenLoaded(isLoggedIn: false, favoriteDoctors: []));
//         return;
//       }
//
//       String? userId = _prefs.getString('userId');
//       if (userId == null) {
//         emit(MainScreenLoaded(isLoggedIn: false, favoriteDoctors: []));
//         return;
//       }
//
//       List<Map<String, dynamic>> favoriteDoctors = [];
//       String? cachedDoctors = _prefs.getString('favoriteDoctors');
//       if (cachedDoctors != null) {
//         try {
//           favoriteDoctors = List<Map<String, dynamic>>.from(json.decode(cachedDoctors));
//         } catch (_) {
//           favoriteDoctors = [];
//         }
//       }
//
//       _hasLoadedOnce = true; // ✅ عند تحميل الصفحة لأول مرة، لا نعيد `Shimmer` مرة أخرى
//       emit(MainScreenLoaded(isLoggedIn: true, favoriteDoctors: favoriteDoctors));
//
//       _favoritesListener?.cancel();
//       _favoritesListener = _firestoreService.listenToFavoriteDoctors(userId).listen((updatedDoctors) async {
//         await _prefs.setString('favoriteDoctors', json.encode(updatedDoctors));
//         emit(MainScreenLoaded(isLoggedIn: true, favoriteDoctors: updatedDoctors));
//       });
//     } catch (e) {
//       emit(MainScreenError("❌ خطأ في تحميل البيانات: $e"));
//     }
//   }
//
//   @override
//   Future<void> close() {
//     _favoritesListener?.cancel();
//     return super.close();
//   }
// }


import 'dart:async';
import 'dart:convert';
import 'package:bloc/bloc.dart';
import 'package:docsera/Business_Logic/Authentication/auth_cubit.dart';
import 'package:docsera/Business_Logic/Authentication/auth_state.dart';
import 'package:docsera/Business_Logic/Main_page/main_screen_state.dart';
import 'package:docsera/services/firestore/firestore_user_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';


class MainScreenCubit extends Cubit<MainScreenState> {
  final FirestoreUserService _firestoreService;
  final SharedPreferences _prefs;
  StreamSubscription? _favoritesListener;
  static bool _hasLoadedOnce = false;

  MainScreenCubit(this._firestoreService, this._prefs) : super(MainScreenLoading());

  Future<void> loadMainScreen(BuildContext context) async {
    try {
      if (!_hasLoadedOnce) {
        emit(MainScreenLoading());
        await Future.delayed(Duration(milliseconds: 100));
      }

      // ✅ استخدم AuthCubit بدل prefs
      final authState = context.read<AuthCubit>().state;

      // ✅ Debug print: تأكيد أن AuthCubit هو المستخدم فعلاً
      print("🔐 AuthCubit State: $authState");

      if (authState is! AuthAuthenticated) {
        emit(MainScreenLoaded(isLoggedIn: false, favoriteDoctors: []));
        return;
      }

      final userId = authState.user.uid;
      print("✅ المستخدم مسجل دخول عبر AuthCubit: $userId");

      List<Map<String, dynamic>> favoriteDoctors = [];
      String? cachedDoctors = _prefs.getString('favoriteDoctors');
      if (cachedDoctors != null) {
        try {
          favoriteDoctors = List<Map<String, dynamic>>.from(json.decode(cachedDoctors));
        } catch (_) {
          favoriteDoctors = [];
        }
      }

      _hasLoadedOnce = true;
      emit(MainScreenLoaded(isLoggedIn: true, favoriteDoctors: favoriteDoctors));

      _favoritesListener?.cancel();
      _favoritesListener = _firestoreService.listenToFavoriteDoctors(userId).listen((updatedDoctors) async {
        await _prefs.setString('favoriteDoctors', json.encode(updatedDoctors));
        emit(MainScreenLoaded(isLoggedIn: true, favoriteDoctors: updatedDoctors));
      });
    } catch (e) {
      emit(MainScreenError("❌ خطأ في تحميل البيانات: $e"));
    }
  }

  @override
  Future<void> close() {
    _favoritesListener?.cancel();
    return super.close();
  }
}
