import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
      DateTime now = DateTime.now();
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('doctors')
          .doc(doctorId)
          .collection('appointments')
          .where('booked', isEqualTo: false)
          .where('timestamp', isGreaterThan: Timestamp.fromDate(now)) // ✅ تصفية المواعيد المستقبلية فقط
          .orderBy('timestamp', descending: false)
          .get();

      Map<String, List<Map<String, dynamic>>> groupedAppointments = {};

      for (var doc in querySnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        DateTime appointmentDate = (data['timestamp'] as Timestamp).toDate();

        String dateKey = DateFormat('EEEE, d MMMM', Localizations.localeOf(context).toString()).format(appointmentDate);

        if (!groupedAppointments.containsKey(dateKey)) {
          groupedAppointments[dateKey] = [];
        }

        groupedAppointments[dateKey]!.add({
          'id': doc.id,
          'time': DateFormat('HH:mm').format(appointmentDate),
          'timestamp': data['timestamp'],
        });
      }

      if (groupedAppointments.isEmpty) {
        emit(DoctorScheduleEmpty());
      } else {
        emit(DoctorScheduleLoaded(groupedAppointments, expandedDates, 6)); // ✅ بدء `maxDisplayedDates` بـ 6
      }

    } catch (e) {
      emit(DoctorScheduleError("❌ Error fetching appointments: $e"));
    }
  }
}
