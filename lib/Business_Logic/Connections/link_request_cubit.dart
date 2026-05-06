// Drives the link-request review screen.
//
// Loads a single pending request by id (via the patient-side service),
// then handles approve / reject by calling rpc_respond_patient_link and
// emitting a terminal state the UI uses to dismiss + show feedback.

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:docsera/services/supabase/patient_link_requests_service.dart';

abstract class LinkRequestState extends Equatable {
  const LinkRequestState();
  @override
  List<Object?> get props => const [];
}

class LinkRequestLoading extends LinkRequestState {
  const LinkRequestLoading();
}

class LinkRequestNotFound extends LinkRequestState {
  const LinkRequestNotFound();
}

class LinkRequestLoaded extends LinkRequestState {
  final PatientLinkRequest request;
  const LinkRequestLoaded(this.request);

  @override
  List<Object?> get props => [request.id, request.kind];
}

class LinkRequestSubmitting extends LinkRequestState {
  final PatientLinkRequest request;
  const LinkRequestSubmitting(this.request);

  @override
  List<Object?> get props => [request.id];
}

class LinkRequestResolved extends LinkRequestState {
  final String resolvedStatus; // 'connected' | 'merged' | 'rejected'
  final bool approved;
  const LinkRequestResolved({required this.resolvedStatus, required this.approved});

  @override
  List<Object?> get props => [resolvedStatus, approved];
}

class LinkRequestFailure extends LinkRequestState {
  final String message;
  const LinkRequestFailure(this.message);

  @override
  List<Object?> get props => [message];
}

class LinkRequestCubit extends Cubit<LinkRequestState> {
  LinkRequestCubit({PatientLinkRequestsService? service})
      : _service = service ?? PatientLinkRequestsService(),
        super(const LinkRequestLoading());

  final PatientLinkRequestsService _service;

  Future<void> load(String requestId) async {
    emit(const LinkRequestLoading());
    try {
      final req = await _service.fetchById(requestId);
      if (req == null) {
        emit(const LinkRequestNotFound());
        return;
      }
      emit(LinkRequestLoaded(req));
    } catch (e) {
      emit(LinkRequestFailure(e.toString()));
    }
  }

  Future<void> respond({required bool approve}) async {
    final current = state;
    if (current is! LinkRequestLoaded) return;
    emit(LinkRequestSubmitting(current.request));
    try {
      final status = await _service.respond(
        requestId: current.request.id,
        approve: approve,
      );
      emit(LinkRequestResolved(resolvedStatus: status, approved: approve));
    } catch (e) {
      emit(LinkRequestFailure(e.toString()));
    }
  }
}
