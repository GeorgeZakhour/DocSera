import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'doctor_schedule_state.dart';

class DoctorScheduleCubit extends Cubit<DoctorScheduleState> {
  DoctorScheduleCubit() : super(DoctorScheduleLoading());

  Set<String> expandedDates = {}; // ✅ تتبع التواريخ الموسعة

  void toggleExpand(String date) {
    if (expandedDates.contains(date)) {
      expandedDates.remove(date);
    } else {
      expandedDates.add(date);
    }

    if (state is DoctorScheduleLoaded) {
      final currentAppointments = (state as DoctorScheduleLoaded).appointments;
      final currentMaxDisplayed = (state as DoctorScheduleLoaded).maxDisplayedDates; // ✅ الحصول على القيمة الحالية
      emit(DoctorScheduleLoaded(currentAppointments, expandedDates, currentMaxDisplayed)); // ✅ الاحتفاظ بالقيمة
    }
  }



  void loadMoreDates(int currentMax) {
    if (state is DoctorScheduleLoaded) {
      final currentAppointments = (state as DoctorScheduleLoaded).appointments;
      final currentExpandedDates = (state as DoctorScheduleLoaded).expandedDates;
      final newMaxDisplayed = currentMax + 3;
      emit(DoctorScheduleLoaded(currentAppointments, currentExpandedDates, newMaxDisplayed)); // ✅ تحديث `maxDisplayedDates`
    }
  }



  Future<void> fetchDoctorAppointments(String doctorId, BuildContext context) async {
    try {
      print('✅ Fetching appointments for doctor: $doctorId'); // 🔹 قبل الطلب

      final now = DateTime.now().toIso8601String();

      final response = await Supabase.instance.client
          .from('appointments')
          .select()
          .eq('doctor_id', doctorId)
          .eq('booked', false)
          .gt('timestamp', now)
          .order('timestamp', ascending: true);


      print('✅ Raw appointments from Supabase: ${response.length}'); // 🔹 بعد الجلب

      if (response.isEmpty) {
        emit(DoctorScheduleEmpty());
        return;
      }

      Map<String, List<Map<String, dynamic>>> groupedAppointments = {};

      for (final data in response) {
        final timestampStr = data['timestamp'];
        if (timestampStr == null) continue;

        final appointmentDate = DateTime.parse(timestampStr);

        final dateKey = DateFormat('EEEE, d MMMM', Localizations.localeOf(context).toString()).format(appointmentDate);

        groupedAppointments.putIfAbsent(dateKey, () => []);

        groupedAppointments[dateKey]!.add({
          'id': data['id'],
          'time': DateFormat('HH:mm').format(appointmentDate),
          'timestamp': appointmentDate,
        });
      }

      if (groupedAppointments.isEmpty) {
        emit(DoctorScheduleEmpty());
      } else {
        emit(DoctorScheduleLoaded(groupedAppointments, expandedDates, 6));
      }
    } catch (e) {
      emit(DoctorScheduleError("❌ Error fetching appointments: $e"));
    }
  }
}
