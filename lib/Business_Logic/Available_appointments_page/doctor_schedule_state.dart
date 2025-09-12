part of 'doctor_schedule_cubit.dart';

abstract class DoctorScheduleState {}

class DoctorScheduleLoading extends DoctorScheduleState {}

class DoctorScheduleLoaded extends DoctorScheduleState {
  final Map<String, List<Map<String, dynamic>>> appointments;
  final Set<String> expandedDates;
  final int maxDisplayedDates;

  DoctorScheduleLoaded(this.appointments, this.expandedDates, this.maxDisplayedDates);
}

class DoctorScheduleEmpty extends DoctorScheduleState {}

class DoctorScheduleError extends DoctorScheduleState {
  final String message;
  DoctorScheduleError(this.message);
}
