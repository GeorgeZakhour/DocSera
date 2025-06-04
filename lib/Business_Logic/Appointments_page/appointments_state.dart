import 'package:equatable/equatable.dart';

/// ✅ Base Class for States
abstract class AppointmentsState extends Equatable {
  const AppointmentsState();

  @override
  List<Object?> get props => [];
}

/// ✅ Initial Loading State
class AppointmentsLoading extends AppointmentsState {}

/// ✅ Loaded Appointments Data
class AppointmentsLoaded extends AppointmentsState {
  final List<Map<String, dynamic>> upcomingAppointments;
  final List<Map<String, dynamic>> pastAppointments;
  final int selectedTab; // ✅ Track last selected tab

  AppointmentsLoaded({
    required this.upcomingAppointments,
    required this.pastAppointments,
    required this.selectedTab, // ✅ Ensure this is included
  });

  @override
  List<Object> get props => [upcomingAppointments, pastAppointments, selectedTab]; // ✅ Add selectedTab here
}


/// ✅ Error State
class AppointmentsError extends AppointmentsState {
  final String message;

  const AppointmentsError(this.message);

  @override
  List<Object?> get props => [message];
}

/// ✅ No Appointments State (When user isn't logged in)
class NotLoggedIn extends AppointmentsState {}
