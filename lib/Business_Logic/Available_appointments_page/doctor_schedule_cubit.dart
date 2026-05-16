import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:docsera/utils/time_utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'doctor_schedule_state.dart';

class DoctorScheduleCubit extends Cubit<DoctorScheduleState> {
  DoctorScheduleCubit() : super(DoctorScheduleLoading());

  /// تتبّع التواريخ الممدّدة في الواجهة
  Set<String> expandedDates = {};

  // =============== Debug helper ===============
  void _dlog(String msg) {
    if (kDebugMode) debugPrint('[Schedule] $msg');
  }

  // ===================== Public API =====================

  void toggleExpand(String date) {
    if (expandedDates.contains(date)) {
      expandedDates.remove(date);
    } else {
      expandedDates.add(date);
    }
    if (state is DoctorScheduleLoaded) {
      final s = state as DoctorScheduleLoaded;
      emit(DoctorScheduleLoaded(s.appointments, expandedDates, s.maxDisplayedDates));
    }
  }

  void loadMoreDates(int currentMax) {
    if (state is DoctorScheduleLoaded) {
      final s = state as DoctorScheduleLoaded;
      emit(DoctorScheduleLoaded(s.appointments, s.expandedDates, currentMax + 3));
    }
  }

  Future<void> fetchDoctorAppointments(
      String doctorId,
      BuildContext context, {
        String? reasonId,
      }) async {
    emit(DoctorScheduleLoading());
    _dlog('=== fetchDoctorAppointments(RPC): doctorId=$doctorId, reasonId=${reasonId ?? "(none)"} ===');
    _dlog('=== fetchDoctorAppointments(RPC) ===');
    _dlog('  doctorId = $doctorId');
    _dlog('  reasonId = ${reasonId ?? "(none)"}');


    try {
      final supabase = Supabase.instance.client;

      // نقرأ إعدادين فقط: نمط الجدولة + مدى الرؤية
      // Discovery query — patients can't open the booking schedule for a
      // doctor whose required profile sections are incomplete.
      final docRow = await supabase
          .from('public_doctors')
          .select('appointment_scheduling_mode, max_visibility_days, min_booking_lead_minutes')
          .eq('id', doctorId)
          .maybeSingle();

      if (docRow == null) {
        emit(DoctorScheduleEmpty());
        return;
      }

      final schedulingMode = (docRow['appointment_scheduling_mode'] as String?) ?? 'default';
      final maxVisibilityDays = (docRow['max_visibility_days'] as int?) ?? 30;
      final minBookingLeadMinutes = (docRow['min_booking_lead_minutes'] as int?) ?? 30;

      // نحضّر باراميترات الـ RPC
      final params = <String, dynamic>{
        'p_doctor_id': doctorId,
        'p_days_ahead': maxVisibilityDays,
      };
      if (schedulingMode == 'custom_by_reason' && (reasonId ?? '').isNotEmpty) {
        params['p_reason_id'] = reasonId;
      }

      // نداء الدالة
      final rows = await supabase.rpc('get_available_slots', params: params);
      final List data = (rows as List?) ?? const [];

      if (data.isEmpty) {
        emit(DoctorScheduleEmpty());
        return;
      }

      // تجميع حسب التاريخ المحلي القادم من الـ RPC (UTC+3)
      final locale = Localizations.localeOf(context).toString();
      final grouped = <String, List<Map<String, dynamic>>>{};

      final now = DocSeraTime.nowSyria();
      final leadCutoff = now.add(Duration(minutes: minBookingLeadMinutes));

      for (final r in data) {
        try {
          final m = Map<String, dynamic>.from(r as Map);
          final tsUtc = DocSeraTime.toUtc(DateTime.parse(m['ts_utc'].toString())); // هذا الذي سنمرّره للحجز

          final dateStr = m['local_date'].toString();              // "YYYY-MM-DD" في UTC+3
          final label12 = m['local_time12'].toString();                 // "HH:MM AM/PM" جاهزة
          final label24 = m['local_time24'].toString();                 // "HH24:MI"

          final dParts = dateStr.split('-');
          final tParts = label24.split(':');
          final yr = int.parse(dParts[0]);
          final mo = int.parse(dParts[1]);
          final dy = int.parse(dParts[2]);
          final hr = int.parse(tParts[0]);
          final mn = int.parse(tParts[1]);

          // Build slot as Syria TZDateTime for accurate lead-time comparison
          final slotLocal = DocSeraTime.syriaDateTime(yr, mo, dy, hr, mn);

          if (!slotLocal.isAfter(leadCutoff)) {
            continue; // 🚫 Skip slots within the booking lead time window
          }

          // صياغة عنوان لطيف للتاريخ (بلغة الجهاز) من "YYYY-MM-DD"
          final d = DocSeraTime.tryParseToSyria(dateStr) ?? DocSeraTime.nowSyria(); // تاريخ فقط
          final dateKey = DateFormat('EEEE, d MMMM', locale).format(d);

          (grouped[dateKey] ??= <Map<String, dynamic>>[]).add({
            'id': tsUtc.toIso8601String(), // نستخدم الـ ts_utc كـ id
            'timestamp': tsUtc,            // للحجز نمرّره كما هو
            'time': label12,               // نعرض 12 ساعة
            'time24': label24,             // متاح إن أردت عرض 24 ساعة
          });
        } catch (e) {
          _dlog('⚠️ skipping invalid row: $r, error: $e');
        }
      }

      // ترتيب المجموعات حسب أول خانة فيها
      final ordered = _sortGroupedByDateKey(grouped, locale);
      emit(DoctorScheduleLoaded(ordered, expandedDates, 6));
    } catch (e, st) {
      _dlog('ERROR (RPC) fetchDoctorAppointments: $e\n$st');
      emit(DoctorScheduleError('❌ Error loading schedule: $e'));
    }
  }

  Map<String, List<Map<String, dynamic>>> _sortGroupedByDateKey(
      Map<String, List<Map<String, dynamic>>> grouped,
      String locale,
      ) {
    final entries = grouped.entries.toList();
    entries.sort((a, b) {
      final aTs = (a.value.isNotEmpty ? a.value.first['timestamp'] as DateTime : null);
      final bTs = (b.value.isNotEmpty ? b.value.first['timestamp'] as DateTime : null);
      if (aTs == null && bTs == null) return 0;
      if (aTs == null) return 1;
      if (bTs == null) return -1;
      return aTs.compareTo(bTs);
    });
    return {for (final e in entries) e.key: e.value};
  }
}
