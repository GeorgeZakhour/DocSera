import 'dart:async';
import 'dart:convert';
import 'package:docsera/Business_Logic/Authentication/auth_cubit.dart';
import 'package:docsera/Business_Logic/Authentication/auth_state.dart';
import 'package:docsera/Business_Logic/Main_page/main_screen_state.dart';
import 'package:docsera/services/supabase/user/supabase_user_service.dart';
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
      // ✅ استخدم AuthCubit بدل prefs — cached before any await so the
      // post-delay use doesn't trip use_build_context_synchronously.
      final authCubit = context.read<AuthCubit>();

      if (!_hasLoadedOnce) {
        emit(MainScreenLoading());
        await Future.delayed(const Duration(milliseconds: 100));
      }

      final authState = authCubit.state;

      // ✅ Debug print: تأكيد أن AuthCubit هو المستخدم فعلاً
      debugPrint("🔐 AuthCubit State: $authState");

      if (authState is! AuthAuthenticated) {
        emit(MainScreenLoaded(isLoggedIn: false, favoriteDoctors: const []));
        return;
      }

      final userId = authState.user.id;
      debugPrint("✅ المستخدم مسجل دخول عبر AuthCubit: $userId");

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
      _favoritesListener =
          _supabaseUserServicee.listenToFavoriteDoctors().listen((updatedDoctors) async {
            await _prefs.setString('favoriteDoctors', json.encode(updatedDoctors));
            emit(MainScreenLoaded(isLoggedIn: true, favoriteDoctors: updatedDoctors));
          });
    } catch (e) {
      emit(MainScreenError("❌ خطأ في تحميل البيانات: $e"));
    }
  }

  Future<void> removeFromFavorites(
      BuildContext context,
      String doctorId,
      ) async {
    final authState = context.read<AuthCubit>().state;
    if (authState is! AuthAuthenticated) return;

    final userId = authState.user.id;

    await _supabaseUserServicee.removeDoctorFromFavorites(userId, doctorId);
    // لا emit — listener سيحدّث الحالة
  }



  @override
  Future<void> close() {
    _favoritesListener?.cancel();
    return super.close();
  }
}
