// Drives the first-booking confirm / dispute screen.
//
// State machine mirrors LinkRequestCubit:
//   loading → loaded | notFound | failure
//   loaded  → submitting → resolved | failure
//
// "resolved" carries the user's choice so the result page can swap copy
// (confirmed → connection settled; disputed → appointment cancelled).

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:docsera/services/supabase/appointment_confirmation_service.dart';

abstract class AppointmentConfirmationState extends Equatable {
  const AppointmentConfirmationState();
  @override
  List<Object?> get props => const [];
}

class AppointmentConfirmationLoading extends AppointmentConfirmationState {
  const AppointmentConfirmationLoading();
}

class AppointmentConfirmationNotFound extends AppointmentConfirmationState {
  const AppointmentConfirmationNotFound();
}

class AppointmentConfirmationLoaded extends AppointmentConfirmationState {
  final FirstBookingAppointment appointment;
  const AppointmentConfirmationLoaded(this.appointment);

  @override
  List<Object?> get props => [appointment.id];
}

class AppointmentConfirmationSubmitting extends AppointmentConfirmationState {
  final FirstBookingAppointment appointment;
  const AppointmentConfirmationSubmitting(this.appointment);

  @override
  List<Object?> get props => [appointment.id];
}

class AppointmentConfirmationResolved extends AppointmentConfirmationState {
  final bool confirmed; // false = disputed
  final String doctorName;
  const AppointmentConfirmationResolved({required this.confirmed, required this.doctorName});

  @override
  List<Object?> get props => [confirmed, doctorName];
}

class AppointmentConfirmationFailure extends AppointmentConfirmationState {
  final String message;
  const AppointmentConfirmationFailure(this.message);

  @override
  List<Object?> get props => [message];
}

class AppointmentConfirmationCubit extends Cubit<AppointmentConfirmationState> {
  AppointmentConfirmationCubit({AppointmentConfirmationService? service})
      : _service = service ?? AppointmentConfirmationService(),
        super(const AppointmentConfirmationLoading());

  final AppointmentConfirmationService _service;

  Future<void> load(String appointmentId) async {
    emit(const AppointmentConfirmationLoading());
    try {
      final appt = await _service.fetchById(appointmentId);
      if (appt == null) {
        emit(const AppointmentConfirmationNotFound());
        return;
      }
      emit(AppointmentConfirmationLoaded(appt));
    } catch (e) {
      emit(AppointmentConfirmationFailure(e.toString()));
    }
  }

  Future<void> respond({required bool confirm}) async {
    final current = state;
    if (current is! AppointmentConfirmationLoaded) return;
    final appt = current.appointment;
    emit(AppointmentConfirmationSubmitting(appt));
    try {
      if (confirm) {
        await _service.confirm(appt.id);
      } else {
        await _service.dispute(appt.id);
      }
      emit(AppointmentConfirmationResolved(
        confirmed: confirm,
        doctorName: appt.doctorName,
      ));
    } catch (e) {
      emit(AppointmentConfirmationFailure(e.toString()));
    }
  }
}
