// import 'dart:async';
// import 'package:bloc/bloc.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:docsera/Business_Logic/Appointments_page/appointments_state.dart';
// import 'package:docsera/services/supabase/supabase_user_service.dart';
// import 'package:shared_preferences/shared_preferences.dart';
//
// class AppointmentsCubit extends Cubit<AppointmentsState> {
//   final FirestoreUserService _firestoreService;
//   final SharedPreferences _prefs;
//   StreamSubscription<List<Map<String, dynamic>>>? _appointmentsSubscription;
//
//   AppointmentsCubit(this._firestoreService, this._prefs) : super(AppointmentsLoading());
//
//   void setAppointmentsFromStream({
//     required List<Map<String, dynamic>> upcoming,
//     required List<Map<String, dynamic>> past,
//   }) {
//     final lastSelectedTab = _prefs.getInt('lastSelectedTab') ?? 0;
//
//     emit(AppointmentsLoaded(
//       upcomingAppointments: upcoming,
//       pastAppointments: past,
//       selectedTab: lastSelectedTab,
//     ));
//   }
//
//
//   /// ✅ **Load Appointments (Fetch from Cache & Firestore)**
//   Future<void> loadAppointments({bool useCache = true}) async {
//     emit(AppointmentsLoading());
//
//     String? userId = _prefs.getString('userId');
//     if (userId == null || userId.isEmpty) {
//       emit(NotLoggedIn());
//       return;
//     }
//
//     try {
//       List<Map<String, dynamic>> upcoming = [];
//       List<Map<String, dynamic>> past = [];
//
//       // ✅ Load last selected tab persistently
//       int lastSelectedTab = _prefs.getInt('lastSelectedTab') ?? 0;
//
//       // ✅ Load from cache first if enabled
//       if (useCache) {
//         var cachedUpcoming = _prefs.getString('upcomingAppointments');
//         var cachedPast = _prefs.getString('pastAppointments');
//
//         if (cachedUpcoming != null && cachedPast != null) {
//           upcoming = List<Map<String, dynamic>>.from(
//               List<dynamic>.from(await _firestoreService.loadCachedData('upcomingAppointments')));
//           past = List<Map<String, dynamic>>.from(
//               List<dynamic>.from(await _firestoreService.loadCachedData('pastAppointments')));
//
//           emit(AppointmentsLoaded(
//             upcomingAppointments: upcoming,
//             pastAppointments: past,
//             selectedTab: lastSelectedTab, // ✅ Store the selected tab
//           ));
//         }
//       }
//
//       // ✅ Fetch fresh data from Firestore
//       final appointments = await _firestoreService.getUserAppointments(userId);
//       upcoming = appointments['upcoming'] ?? [];
//       past = appointments['past'] ?? [];
//
//       emit(AppointmentsLoaded(
//         upcomingAppointments: upcoming,
//         pastAppointments: past,
//         selectedTab: lastSelectedTab, // ✅ Ensure correct tab selection
//       ));
//
//       // ✅ Save fetched data in SharedPreferences
//       await _firestoreService.saveCachedData('upcomingAppointments', upcoming);
//       await _firestoreService.saveCachedData('pastAppointments', past);
//
//       // ✅ Start listening for real-time updates
//       _listenToAppointments(userId);
//
//     } catch (e) {
//       emit(AppointmentsError("Failed to load appointments: $e"));
//     }
//   }
//
//   /// **🔥 Real-time Firestore Listener**
//   void _listenToAppointments(String userId) {
//     _appointmentsSubscription?.cancel();
//     _appointmentsSubscription = _firestoreService.listenToUserAppointments(userId).listen((appointments) async {
//       List<Map<String, dynamic>> upcoming = [];
//       List<Map<String, dynamic>> past = [];
//
//       for (var appointment in appointments) {
//         DateTime appointmentDate = DateTime.parse(appointment['timestamp']);
//         if (appointmentDate.isAfter(DateTime.now())) {
//           upcoming.add(appointment);
//         } else {
//           past.add(appointment);
//         }
//       }
//
//       int lastSelectedTab = _prefs.getInt('lastSelectedTab') ?? 0;
//
//       emit(AppointmentsLoaded(
//         upcomingAppointments: upcoming,
//         pastAppointments: past,
//         selectedTab: lastSelectedTab, // ✅ Maintain last tab selection
//       ));
//
//       // ✅ Save updated data in cache
//       await _firestoreService.saveCachedData('upcomingAppointments', upcoming);
//       await _firestoreService.saveCachedData('pastAppointments', past);
//     });
//   }
//
//   /// **🔹 Update Selected Tab Persistently**
//   void updateSelectedTab(int tabIndex) {
//     _prefs.setInt('lastSelectedTab', tabIndex); // ✅ Save last selected tab
//     if (state is AppointmentsLoaded) {
//       var loadedState = state as AppointmentsLoaded;
//       emit(AppointmentsLoaded(
//         upcomingAppointments: loadedState.upcomingAppointments,
//         pastAppointments: loadedState.pastAppointments,
//         selectedTab: tabIndex, // ✅ Ensure tab selection is stored
//       ));
//     }
//   }
//
//   /// **🔹 Logout: Clear Data & Stop Listening**
//   Future<void> logout() async {
//     await _prefs.clear();
//     _appointmentsSubscription?.cancel();
//     emit(NotLoggedIn());
//   }
//
//   @override
//   Future<void> close() {
//     _appointmentsSubscription?.cancel();
//     return super.close();
//   }
// }

import 'dart:async';
import 'package:docsera/Business_Logic/Appointments_page/appointments_state.dart';
import 'package:docsera/Business_Logic/Authentication/auth_cubit.dart';
import 'package:docsera/Business_Logic/Authentication/auth_state.dart';
import 'package:docsera/services/supabase/user/supabase_user_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';


class AppointmentsCubit extends Cubit<AppointmentsState> {
  final SupabaseUserService _supabaseUserService;
  final SharedPreferences _prefs;
  StreamSubscription<List<Map<String, dynamic>>>? _appointmentsSubscription;

  AppointmentsCubit(this._supabaseUserService, this._prefs) : super(AppointmentsLoading());

  void setAppointmentsFromStream({
    required List<Map<String, dynamic>> upcoming,
    required List<Map<String, dynamic>> past,
  }) {
    final lastSelectedTab = _prefs.getInt('lastSelectedTab') ?? 0;

    emit(AppointmentsLoaded(
      upcomingAppointments: upcoming,
      pastAppointments: past,
      selectedTab: lastSelectedTab,
    ));
  }

  String? _loadedUserId;

  /// ✅ Load Appointments using AuthCubit or explicitUserId
  Future<void> loadAppointments({BuildContext? context, String? explicitUserId, bool useCache = true, bool forceReload = false}) async {
    String? userId;
    if (explicitUserId != null) {
      userId = explicitUserId;
    } else if (context != null) {
      final authState = context.read<AuthCubit>().state;
      debugPrint("🔐 AuthCubit State (Appointment cubit): $authState");
      if (authState is AuthAuthenticated) {
        userId = authState.user.id;
      }
    }

    if (userId == null) {
      emit(NotLoggedIn());
      return;
    }

    // ✅ Secure Cache Check: Must match current User ID
    if (!forceReload && state is AppointmentsLoaded && _loadedUserId == userId) return;

    _loadedUserId = userId; // Update loaded user ID

    emit(AppointmentsLoading());
    debugPrint("✅  المستخدم مسجل دخول عبر(Appointment cubit): $userId");

    try {
      List<Map<String, dynamic>> upcoming = [];
      List<Map<String, dynamic>> past = [];

      int lastSelectedTab = _prefs.getInt('lastSelectedTab') ?? 0;

      if (useCache) {
        var cachedUpcoming = _prefs.getString('upcomingAppointments');
        var cachedPast = _prefs.getString('pastAppointments');

        if (cachedUpcoming != null && cachedPast != null) {
          upcoming = List<Map<String, dynamic>>.from(
              List<dynamic>.from(await _supabaseUserService.loadCachedData('upcomingAppointments')));
          past = List<Map<String, dynamic>>.from(
              List<dynamic>.from(await _supabaseUserService.loadCachedData('pastAppointments')));

          emit(AppointmentsLoaded(
            upcomingAppointments: upcoming,
            pastAppointments: past,
            selectedTab: lastSelectedTab,
          ));
        }
      }

      final appointments = await _supabaseUserService.getUserAppointments(userId);
      upcoming = appointments['upcoming'] ?? [];
      past = appointments['past'] ?? [];

      emit(AppointmentsLoaded(
        upcomingAppointments: upcoming,
        pastAppointments: past,
        selectedTab: lastSelectedTab,
      ));

      await _supabaseUserService.saveCachedData('upcomingAppointments', upcoming);
      await _supabaseUserService.saveCachedData('pastAppointments', past);

      _listenToAppointments(userId);
    } catch (e) {
      _loadedUserId = null; // Reset on failure
      emit(AppointmentsError("Failed to load appointments: $e"));
    }
  }

  void _listenToAppointments(String userId) {
    _appointmentsSubscription?.cancel();
    _appointmentsSubscription = _supabaseUserService.listenToUserAppointments(userId).listen((appointments) async {
      List<Map<String, dynamic>> upcoming = [];
      List<Map<String, dynamic>> past = [];

      for (var appointment in appointments) {
        DateTime appointmentDate = DateTime.parse(appointment['timestamp']);
        if (appointmentDate.isAfter(DateTime.now())) {
          upcoming.add(appointment);
        } else {
          past.add(appointment);
        }
      }

      int lastSelectedTab = _prefs.getInt('lastSelectedTab') ?? 0;

      emit(AppointmentsLoaded(
        upcomingAppointments: upcoming,
        pastAppointments: past,
        selectedTab: lastSelectedTab,
      ));

      await _supabaseUserService.saveCachedData('upcomingAppointments', upcoming);
      await _supabaseUserService.saveCachedData('pastAppointments', past);
    });
  }

  void updateSelectedTab(int tabIndex) {
    _prefs.setInt('lastSelectedTab', tabIndex);
    if (state is AppointmentsLoaded) {
      var loadedState = state as AppointmentsLoaded;
      emit(AppointmentsLoaded(
        upcomingAppointments: loadedState.upcomingAppointments,
        pastAppointments: loadedState.pastAppointments,
        selectedTab: tabIndex,
      ));
    }
  }

  Future<void> logout() async {
    await _prefs.clear();
    _appointmentsSubscription?.cancel();
    emit(NotLoggedIn());
  }

  @override
  Future<void> close() {
    _appointmentsSubscription?.cancel();
    return super.close();
  }
}
