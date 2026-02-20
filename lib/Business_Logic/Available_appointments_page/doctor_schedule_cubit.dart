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

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

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

  @override
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
      final docRow = await supabase
          .from('doctors')
          .select('appointment_scheduling_mode, max_visibility_days')
          .eq('id', doctorId)
          .maybeSingle();

      if (docRow == null) {
        emit(DoctorScheduleEmpty());
        return;
      }

      final schedulingMode = (docRow['appointment_scheduling_mode'] as String?) ?? 'default';
      final maxVisibilityDays = (docRow['max_visibility_days'] as int?) ?? 30;

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

      for (final r in data) {
        try {
          final m = Map<String, dynamic>.from(r as Map);
          final tsUtc = DocSeraTime.toUtc(DateTime.parse(m['ts_utc'].toString())); // هذا الذي سنمرّره للحجز
          final localDateStr = m['local_date'].toString();              // "YYYY-MM-DD" في UTC+3
          final label12 = m['local_time12'].toString();                 // "HH:MM AM/PM" جاهزة
          final label24 = m['local_time24'].toString();                 // "HH24:MI"

          // صياغة عنوان لطيف للتاريخ (بلغة الجهاز) من "YYYY-MM-DD"
          final d = DocSeraTime.tryParseToSyria(localDateStr) ?? DocSeraTime.nowSyria(); // تاريخ فقط
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

  Map<String, List<Map<String, String>>> _normalizeOpeningHoursKeys(Map input) {
    final out = <String, List<Map<String, String>>>{};
    input.forEach((key, value) {
      final day = _normDay(key.toString());
      final list = (value as List? ?? []).map((e) => Map<String, String>.from(e as Map)).toList();
      out[day] = list;
    });
    return out;
  }

  String _normDay(String d) {
    final s = (d).toLowerCase().trim();
    if (s.startsWith('mon') || s == 'mo') return 'mon';
    if (s.startsWith('tue') || s == 'tu') return 'tue';
    if (s.startsWith('wed') || s == 'we') return 'wed';
    if (s.startsWith('thu') || s == 'th') return 'thu';
    if (s.startsWith('fri') || s == 'fr') return 'fri';
    if (s.startsWith('sat') || s == 'sa') return 'sat';
    if (s.startsWith('sun') || s == 'su') return 'sun';
    return s.length >= 3 ? s.substring(0, 3) : s;
  }

  String _normDayByDate(DateTime date) {
    switch (date.weekday) {
      case DateTime.monday:
        return 'mon';
      case DateTime.tuesday:
        return 'tue';
      case DateTime.wednesday:
        return 'wed';
      case DateTime.thursday:
        return 'thu';
      case DateTime.friday:
        return 'fri';
      case DateTime.saturday:
        return 'sat';
      case DateTime.sunday:
      default:
        return 'sun';
    }
  }

  // ---- Flexible time parsing / formatting ----

  int _toMinutesFlexible(String raw) {
    // Accepts: "HH:MM", "HH:MM:SS", "h:MM AM/PM", "HH:MM AM/PM"
    final t = raw.trim().toUpperCase();
    final hasAm = t.endsWith('AM');
    final hasPm = t.endsWith('PM');

    String core = t;
    if (hasAm || hasPm) {
      core = t.replaceAll('AM', '').replaceAll('PM', '').trim();
    }

    final parts = core.split(':');
    if (parts.length < 2) {
      throw FormatException('Invalid time format: "$raw"');
    }

    int h = int.parse(parts[0]);
    int m = int.parse(parts[1].replaceAll(RegExp(r'[^0-9]'), '')); // strip seconds or any suffix

    if (hasAm || hasPm) {
      if (hasAm) {
        if (h == 12) h = 0; // 12:xx AM → 00:xx
      } else {
        // PM
        if (h != 12) h += 12;
      }
    }

    return h * 60 + m;
  }

  String _toHHMM(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  // ---- Coalesce contiguous/overlapping ranges ----

  List<Map<String, String>> _coalesceRanges(List<Map<String, String>> ranges) {
    final intervals = <List<int>>[];

    for (final r in ranges) {
      final from = (r['from'] ?? r['start'] ?? r['start_time'] ?? '').toString().trim();
      final to = (r['to'] ?? r['end'] ?? r['end_time'] ?? '').toString().trim();
      if (from.isEmpty || to.isEmpty) continue;
      try {
        final s = _toMinutesFlexible(from);
        final e = _toMinutesFlexible(to);
        if (e > s) intervals.add([s, e]);
      } catch (e) {
        _dlog('Coalesce skip bad time range: $r ($e)');
      }
    }

    if (intervals.isEmpty) return const <Map<String, String>>[];

    intervals.sort((a, b) => a[0].compareTo(b[0]));

    final merged = <List<int>>[];
    for (final cur in intervals) {
      if (merged.isEmpty) {
        merged.add([cur[0], cur[1]]);
        continue;
      }
      final last = merged.last;
      if (cur[0] <= last[1]) {
        // overlap or contiguous
        if (cur[1] > last[1]) last[1] = cur[1];
      } else {
        merged.add([cur[0], cur[1]]);
      }
    }

    return [
      for (final m in merged) {'from': _toHHMM(m[0]), 'to': _toHHMM(m[1])}
    ];
  }

  List<Map<String, String>> _sliceRange(String from, String to, int duration) {
    final start = _toMinutesFlexible(from);
    final end = _toMinutesFlexible(to);
    final slots = <Map<String, String>>[];

    int cur = start;
    while (cur + duration <= end) {
      final next = cur + duration;
      slots.add({'start': _toHHMM(cur), 'end': _toHHMM(next)});
      cur = next;
    }
    return slots;
  }

  DateTime _dateAtHHMM(DateTime date, String hhmm) {
    final parts = hhmm.split(':');
    final h = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    return DateTime(date.year, date.month, date.day, h, m);
  }

  String _formatSlotLabel(BuildContext context, String startHHMM, String endHHMM) {
    final localizations = MaterialLocalizations.of(context);
    final startTOD = _toTimeOfDay(startHHMM);
    final endTOD = _toTimeOfDay(endHHMM);
    final s = localizations.formatTimeOfDay(startTOD, alwaysUse24HourFormat: false);
    final e = localizations.formatTimeOfDay(endTOD, alwaysUse24HourFormat: false);
    return '$s → $e';
  }

  TimeOfDay _toTimeOfDay(String hhmm) {
    final p = hhmm.split(':');
    return TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
  }

  int _epochMinute(DateTime dtUtc) {
    return dtUtc.millisecondsSinceEpoch ~/ (60 * 1000);
  }

  Future<Set<int>> _loadReservedTimestamps(
      SupabaseClient supabase,
      String doctorId,
      DateTime from,
      DateTime to,
      ) async {
    final fromIso = from.toUtc().toIso8601String();
    final toIso = to.toUtc().toIso8601String();

    try {
      final rows = await supabase
          .from('appointments')
          .select('timestamp')
          .eq('doctor_id', doctorId)
          .gte('timestamp', fromIso)
          .lte('timestamp', toIso);

      final set = <int>{};
      for (final r in (rows as List? ?? [])) {
        final tsStr = r['timestamp'];
        if (tsStr == null) continue;
        final ts = DocSeraTime.toUtc(DateTime.parse(tsStr));
        set.add(_epochMinute(ts));
      }
      _dlog('Loaded reserved timestamps: ${set.length}');
      return set;
    } catch (e) {
      _dlog('ERROR loading reserved timestamps: $e');
      return <int>{};
    }
  }

  /// ✅ التحميل المباشر من جدول doctor_vacations باستخدام doctor_id
  Future<List<Map<String, dynamic>>> _loadVacationsDirect(
      SupabaseClient supabase,
      String doctorId,
      ) async {
    try {
      final rows = await supabase
          .from('doctor_vacations')
          .select('start_date, end_date')
          .eq('doctor_id', doctorId);

      final list = (rows as List? ?? [])
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      _dlog('Vacations from table: ${list.length}');
      return list;
    } catch (e) {
      _dlog('ERROR reading doctor_vacations: $e');
      return <Map<String, dynamic>>[];
    }
  }

  Set<DateTime> _expandVacationDays(List<Map<String, dynamic>> vacations) {
    final set = <DateTime>{};
    for (final v in vacations) {
      final start = _toDateOnly(v['start_date']);
      final end = _toDateOnly(v['end_date']);
      if (start == null || end == null) {
        _dlog('Bad vacation row (cannot parse dates): $v');
        continue;
      }
      DateTime cur = start;
      while (!cur.isAfter(end)) {
        set.add(DateTime(cur.year, cur.month, cur.day));
        cur = cur.add(const Duration(days: 1));
      }
    }
    return set;
  }

  bool _isVacationDay(DateTime date, Set<DateTime> vacSet) {
    final d = DateTime(date.year, date.month, date.day);
    return vacSet.contains(d);
  }

  DateTime? _toDateOnly(dynamic value) {
    if (value == null) return null;
    try {
      if (value is DateTime) {
        return DateTime(value.year, value.month, value.day);
      }
      final dt = DocSeraTime.tryParseToSyria(value.toString()) ?? DocSeraTime.nowSyria();
      return DateTime(dt.year, dt.month, dt.day);
    } catch (e) {
      _dlog('Cannot parse date-only from value="$value": $e');
      return null;
    }
  }

  Future<Map<String, List<Map<String, String>>>> _loadReasonSlotsForReason(
      SupabaseClient supabase,
      String doctorId,
      String reasonId,
      ) async {
    try {
      final rows = await supabase
          .from('reason_time_slots')
          .select('day_of_week, start_time, end_time')
          .eq('doctor_id', doctorId)
          .eq('reason_id', reasonId);

      _dlog('Reason time slots rows: ${(rows as List?)?.length ?? 0} for reason=$reasonId');

      final map = <String, List<Map<String, String>>>{};
      for (final row in (rows as List? ?? [])) {
        final r = Map<String, dynamic>.from(row as Map);
        final day = _normDay(r['day_of_week']?.toString() ?? '');
        final start = (r['start_time'] ?? '').toString();
        final end = (r['end_time'] ?? '').toString();
        if (start.isEmpty || end.isEmpty) {
          _dlog('Bad slot row: $row');
          continue;
        }
        (map[day] ??= <Map<String, String>>[]).add({'from': start, 'to': end});
      }
      return map;
    } catch (e) {
      _dlog('ERROR loading reason slots: $e');
      return <String, List<Map<String, String>>>{};
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
