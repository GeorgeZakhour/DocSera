import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:docsera/services/supabase/repositories/auth_repository.dart';
import 'package:docsera/services/supabase/repositories/user_repository.dart';
import 'package:docsera/services/supabase/repositories/favorites_repository.dart';
import 'package:docsera/services/supabase/repositories/appointment_repository.dart';

class SupabaseUserService {
  final AuthRepository auth;
  final UserRepository user;
  final FavoritesRepository favorites;
  final AppointmentRepository appointments;

  SupabaseUserService({
    required this.auth,
    required this.user,
    required this.favorites,
    required this.appointments,
  });

  // --- Auth & Security Delegates ---

  Future<bool> isPhoneNumberExists(String phoneNumber) => 
      auth.isPhoneNumberExists(phoneNumber);

  Future<AuthResponse> signInWithPassword({required String email, required String password}) => 
      auth.signInWithPassword(email: email, password: password);

  Future<void> signOut() => auth.signOut();

  User? getCurrentUser() => auth.getCurrentUser();

  Future<Map<String, dynamic>> getLoginInfoByEmailOrPhone(String input) => 
      auth.getLoginInfoByEmailOrPhone(input);

  Future<Map<String, dynamic>> getMySecurityState() => 
      auth.getMySecurityState();

  Future<bool> doesUserExist({String? email, String? phoneNumber}) => 
      auth.doesUserExist(email: email, phoneNumber: phoneNumber);

  Future<void> deleteUserAccount() => auth.deleteUserAccount();

  // --- User Profile Delegates ---

  Future<void> addUser(Map<String, dynamic> userData) => 
      user.addUser(userData);

  Future<Map<String, dynamic>?> getUserData(String userId) => 
      user.getUserData(userId);

  Future<void> updateUser(String userId, Map<String, dynamic> updatedData) => 
      user.updateUser(userId, updatedData);

  Future<List<Map<String, dynamic>>> getPaginatedUsers({String? lastCreatedAt, int limit = 10}) => 
      user.getPaginatedUsers(lastCreatedAt: lastCreatedAt, limit: limit);

  // --- Favorites Delegates ---

  Future<List<String>> getUserFavorites(String userId) => 
      favorites.getUserFavorites(userId);

  Future<void> updateUserFavorites(String userId, List<String> favs) => 
      favorites.updateUserFavorites(userId, favs);

  Future<List<Map<String, dynamic>>> getFavoriteDoctors() => 
      favorites.getFavoriteDoctors();

  Future<void> removeDoctorFromFavorites(String userId, String doctorId) => 
      favorites.removeDoctorFromFavorites(userId, doctorId);

  Stream<List<Map<String, dynamic>>> listenToFavoriteDoctors() => 
      favorites.listenToFavoriteDoctors();
      
  Future<List<dynamic>> loadCachedData(String key) => 
      favorites.loadCachedData(key); // Re-using favorites access to shared prefs helper if needed, or arguably duplicate in repos.
      // Note: loadCachedData was generic in original. I implemented it in FavoritesRepository. 
      // If other parts use it via SupabaseUserService, this delegation works.

  Future<void> saveCachedData(String key, List<Map<String, dynamic>> data) => 
      favorites.saveCachedData(key, data);


  // --- Appointment Delegates ---

  Future<Map<String, List<Map<String, dynamic>>>> getUserAppointments(String userId) => 
      appointments.getUserAppointments(userId);

  Stream<List<Map<String, dynamic>>> listenToUserAppointments(String userId) => 
      appointments.listenToUserAppointments(userId);

  void listenToAppointments(String userId) => 
      appointments.listenToAppointments(userId);

  void cancelAppointmentsListener() => 
      appointments.cancelAppointmentsListener();

  Future<void> clearAppointmentCache() => 
      appointments.clearAppointmentCache();
}
