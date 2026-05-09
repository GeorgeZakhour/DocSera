// Data layer for the first-booking confirm / dispute flow on the patient
// side. Surfaces a single appointment by id (denormalized doctor fields
// come straight from the appointments row) and exposes the two RPCs
// that close the loop:
//
//   rpc_confirm_first_appointment(p_appointment_id) — promotes the
//     pending doctor_patient_links row to 'connected'. Future bookings
//     between this doctor and patient are silent operational from now on.
//
//   rpc_dispute_first_appointment(p_appointment_id) — cancels the
//     appointment, marks the link 'disputed', writes a row to
//     link_dispute_audit. Doctor must use the connection-request flow
//     to re-establish trust.

import 'package:supabase_flutter/supabase_flutter.dart';

/// One appointment row hydrated for the confirm / dispute UI.
/// Doctor presentation fields come denormalized from the appointment row
/// (doctor_name, doctor_image, etc.), no extra join required.
class FirstBookingAppointment {
  final String id;
  final String doctorId;
  final String doctorName;
  final String? doctorImage;
  final String? doctorTitle;
  final String? doctorGender;
  final String? doctorSpecialty;
  final String? clinic;
  final String? clinicAddressLine;
  final DateTime appointmentDateTime;
  final String? reason;
  final String? patientName;
  final String? bookedBy;            // 'doctor' | 'patient'
  final String? status;              // 'not_arrived' / 'cancelled_*' / etc.
  final bool isForRelative;

  const FirstBookingAppointment({
    required this.id,
    required this.doctorId,
    required this.doctorName,
    required this.doctorImage,
    required this.doctorTitle,
    required this.doctorGender,
    required this.doctorSpecialty,
    required this.clinic,
    required this.clinicAddressLine,
    required this.appointmentDateTime,
    required this.reason,
    required this.patientName,
    required this.bookedBy,
    required this.status,
    required this.isForRelative,
  });

  /// True when the appointment is still in a state that the patient can
  /// act on — not already cancelled, not yet completed.
  bool get isActionable {
    final s = status ?? '';
    return s != 'cancelled_by_patient' &&
        s != 'cancelled_by_doctor' &&
        s != 'cancelled' &&
        s != 'never_arrived_cancelled' &&
        s != 'done';
  }

  factory FirstBookingAppointment.fromMap(Map<String, dynamic> m) {
    final dateStr = m['appointment_date']?.toString() ?? '';
    final timeStr = m['appointment_time']?.toString() ?? '00:00:00';
    DateTime dt;
    try {
      dt = DateTime.parse('${dateStr}T$timeStr');
    } catch (_) {
      dt = DateTime.tryParse(m['timestamp']?.toString() ?? '') ?? DateTime.now();
    }

    String? clinicAddr;
    final addr = m['clinic_address'];
    if (addr is Map) {
      clinicAddr = (addr['line1'] ?? addr['address'] ?? addr['street'])?.toString();
    } else if (addr is String) {
      clinicAddr = addr;
    }

    return FirstBookingAppointment(
      id: m['id'] as String,
      doctorId: m['doctor_id'] as String,
      doctorName: (m['doctor_name'] as String?)?.trim() ?? '',
      doctorImage: m['doctor_image'] as String?,
      doctorTitle: m['doctor_title'] as String?,
      doctorGender: m['doctor_gender'] as String?,
      doctorSpecialty: m['doctor_specialty'] as String?,
      clinic: m['clinic'] as String?,
      clinicAddressLine: clinicAddr,
      appointmentDateTime: dt,
      reason: m['reason'] as String?,
      patientName: m['patient_name'] as String?,
      bookedBy: m['booked_by'] as String?,
      status: m['status'] as String?,
      isForRelative: m['relative_id'] != null,
    );
  }
}

class AppointmentConfirmationService {
  AppointmentConfirmationService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// RLS gates the read to the caller's own appointments (or those of
  /// their relatives). A null result means the appointment doesn't
  /// exist or doesn't belong to the caller.
  Future<FirstBookingAppointment?> fetchById(String appointmentId) async {
    final row = await _client
        .from('appointments')
        .select()
        .eq('id', appointmentId)
        .maybeSingle();
    if (row == null) return null;
    return FirstBookingAppointment.fromMap(Map<String, dynamic>.from(row));
  }

  Future<void> confirm(String appointmentId) async {
    await _client.rpc(
      'rpc_confirm_first_appointment',
      params: {'p_appointment_id': appointmentId},
    );
  }

  Future<void> dispute(String appointmentId) async {
    await _client.rpc(
      'rpc_dispute_first_appointment',
      params: {'p_appointment_id': appointmentId},
    );
  }
}
