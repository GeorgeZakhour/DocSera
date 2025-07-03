import 'dart:async';
import 'dart:convert';
import 'package:bloc/bloc.dart';
import 'package:docsera/Business_Logic/Authentication/auth_cubit.dart';
import 'package:docsera/Business_Logic/Authentication/auth_state.dart';
import 'package:docsera/Business_Logic/Main_page/main_screen_state.dart';
import 'package:docsera/services/supabase/supabase_user_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';


class MainScreenCubit extends Cubit<MainScreenState> {
  final SupabaseUserService _supabaseUserServicee;
  final SharedPreferences _prefs;
  StreamSubscription? _favoritesListener;
  static bool _hasLoadedOnce = false;

  MainScreenCubit(this._supabaseUserServicee, this._prefs) : super(MainScreenLoading());

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

      final userId = authState.user.id;
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
      _favoritesListener = _supabaseUserServicee.listenToFavoriteDoctors(userId).listen((updatedDoctors) async {
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
