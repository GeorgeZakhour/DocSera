part of 'doctor_schedule_cubit.dart';

abstract class DoctorScheduleState {}

class DoctorScheduleLoading extends DoctorScheduleState {}

class DoctorScheduleLoaded extends DoctorScheduleState {
  final Map<String, List<Map<String, dynamic>>> appointments;
  final Set<String> expandedDates;
  final int maxDisplayedDates; // ✅ أضف المتغير الثالث

  DoctorScheduleLoaded(this.appointments, this.expandedDates, this.maxDisplayedDates);
}



class DoctorScheduleExpanded extends DoctorScheduleState {
  final Set<String> expandedDates;
  DoctorScheduleExpanded(this.expandedDates);
}
class DoctorScheduleMoreDatesLoaded extends DoctorScheduleState {
  final int maxDisplayedDates;
  DoctorScheduleMoreDatesLoaded(this.maxDisplayedDates);
}

class DoctorScheduleEmpty extends DoctorScheduleState {}

class DoctorScheduleError extends DoctorScheduleState {
  final String message;
  DoctorScheduleError(this.message);
}
