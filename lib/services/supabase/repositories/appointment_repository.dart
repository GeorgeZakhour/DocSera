import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:docsera/utils/shared_prefs_service.dart';
import '../../../utils/time_utils.dart';

class AppointmentRepository {
  final SupabaseClient _supabase;
  final SharedPrefsService _sharedPrefsService = SharedPrefsService();
  StreamSubscription<List<Map<String, dynamic>>>? _appointmentsListener;

  AppointmentRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  /// ✅ جلب مواعيد المستخدم مع تصنيفها (قادمة / سابقة)
  Future<Map<String, List<Map<String, dynamic>>>> getUserAppointments(String userId) async {
    try {
      // ✅ جلب من الكاش أولًا
      final cachedUpcoming = await _sharedPrefsService.loadData('upcomingAppointments') ?? [];
      final cachedPast = await _sharedPrefsService.loadData('pastAppointments') ?? [];

      if (cachedUpcoming.isNotEmpty || cachedPast.isNotEmpty) {
        debugPrint("⚡ Loaded appointments from cache");
        return {
          'upcoming': List<Map<String, dynamic>>.from(cachedUpcoming),
          'past': List<Map<String, dynamic>>.from(cachedPast),
        };
      }

      final nowUtc = DocSeraTime.nowUtc().toIso8601String();

      // ✅ 1. Get Upcoming Appointments (Future -> Now)
      final upcomingResponse = await _supabase
          .from('appointments')
          .select()
          .eq('user_id', userId)
          .gte('timestamp', nowUtc) // Only future items
          .order('timestamp', ascending: true);

      // ✅ 2. Get Past Appointments (History) - LIMITED to 5
      final pastResponse = await _supabase
          .from('appointments')
          .select()
          .eq('user_id', userId)
          .lt('timestamp', nowUtc) // Only past items
          .order('timestamp', ascending: false) // Newest past first
          .limit(5); // ✅ COST SAVING: Only fetch recent history

      final allData = [...upcomingResponse, ...pastResponse];

      List<Map<String, dynamic>> upcoming = [];
      List<Map<String, dynamic>> past = [];

      final nowSyria = DocSeraTime.nowSyria();

      for (var appt in allData) {
        final status = (appt['status'] ?? '').toString();
        final isRejected = status == 'rejected';
        final isBooked = appt['booked'] == true;

        if (!isBooked && !isRejected) continue;

        final timestampUtc = DateTime.tryParse(appt['timestamp'] ?? '')?.toUtc();
        final timestamp = DocSeraTime.toSyria(timestampUtc ?? nowSyria);

        if (appt.containsKey('booking_timestamp')) {
          appt['booking_timestamp'] = appt['booking_timestamp']?.toString();
        }

        appt['timestamp'] = timestamp.toIso8601String();

        if (timestamp.isAfter(nowSyria)) {
          upcoming.add(appt);
        } else {
          past.add(appt);
        }
      }

      await _sharedPrefsService.saveData('upcomingAppointments', upcoming);
      await _sharedPrefsService.saveData('pastAppointments', past);

      return {
        'upcoming': List<Map<String, dynamic>>.from(upcoming),
        'past': List<Map<String, dynamic>>.from(past),
      };
    } catch (e) {
      debugPrint("❌ Error fetching appointments: $e");
      return {'upcoming': [], 'past': []};
    }
  }

  /// ✅ الاستماع للمواعيد في الوقت الفعلي (يتطلب تفعيل Realtime في Supabase)
  Stream<List<Map<String, dynamic>>> listenToUserAppointments(String userId) {
    final stream = _supabase
        .from('appointments')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('timestamp', ascending: true)
        .map((event) {
      final now = DocSeraTime.nowSyria();
      List<Map<String, dynamic>> all = [];

      for (final appt in event) {
        final status = (appt['status'] ?? '').toString();
        final isRejected = status == 'rejected';
        final isBooked = appt['booked'] == true;

        // ✅ نسمح فقط بالمواعيد المحجوزة أو المرفوضة
        if (!isBooked && !isRejected) continue;

        final timestampUtc = DocSeraTime.tryParseToSyria(appt['timestamp'] ?? '')?.toUtc();
        final timestamp = DocSeraTime.toSyria(timestampUtc ?? now);

        appt['timestamp'] = timestamp.toIso8601String();
        appt['booking_timestamp'] = appt['booking_timestamp']?.toString();

        all.add(appt);
      }

      final upcoming = all.where((a) => DocSeraTime.tryParseToSyria(a['timestamp'])!.isAfter(now)).toList();
      final past = all.where((a) => DocSeraTime.tryParseToSyria(a['timestamp'])!.isBefore(now)).toList();

      _sharedPrefsService.saveData('upcomingAppointments', upcoming);
      _sharedPrefsService.saveData('pastAppointments', past);

      debugPrint("🔥 Appointments updated via realtime");

      return [...upcoming, ...past];
    });

    return stream;
  }

  /// ✅ تفعيل الاستماع للمواعيد
  void listenToAppointments(String userId) {
    _appointmentsListener?.cancel();
    _appointmentsListener = listenToUserAppointments(userId).listen((_) {
      debugPrint("📡 Appointments listener triggered.");
    });
  }

  /// ✅ إلغاء الاستماع
  void cancelAppointmentsListener() {
    _appointmentsListener?.cancel();
    _appointmentsListener = null;
    debugPrint("🛑 Appointments listener canceled.");
  }

  /// ✅ مسح كاش المواعيد
  Future<void> clearAppointmentCache() async {
    await _sharedPrefsService.removeData('upcomingAppointments');
    await _sharedPrefsService.removeData('pastAppointments');
    debugPrint("🧹 Appointment cache cleared.");
  }
}
