// Drives the Connections Center — the unified surface that lists every
// pending patient↔doctor link request the user can act on. Handles
// approve/decline directly so cards can act inline without bouncing
// through the dedicated review page (the review page is still reachable
// as a "details" deep-dive from each card).
//
// State machine:
//   loading       — initial fetch
//   loaded        — pending list rendered, no card busy
//   actingOnId    — one specific card is mid-respond (server round-trip)
//   error         — fetch failed (full-screen retry surface)
//
// Notably this cubit STAYS LOADED after a respond — the request that
// just resolved is removed from the list, and the next request (if any)
// becomes the new top card. Only when the list goes empty does the UI
// show the "all clear" state.

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:docsera/services/supabase/patient_link_requests_service.dart';

abstract class ConnectionsCenterState extends Equatable {
  const ConnectionsCenterState();
  @override
  List<Object?> get props => const [];
}

class ConnectionsCenterLoading extends ConnectionsCenterState {
  const ConnectionsCenterLoading();
}

class ConnectionsCenterLoaded extends ConnectionsCenterState {
  final List<PatientLinkRequest> requests;

  /// id of a request currently being approved/declined; null when idle.
  final String? actingOnId;

  /// Tracks the most recently resolved request — used by the UI to
  /// drive the in-card success animation before the row is removed
  /// from the list. Cleared on next refresh.
  final ResolvedRequest? lastResolved;

  const ConnectionsCenterLoaded({
    required this.requests,
    this.actingOnId,
    this.lastResolved,
  });

  bool get isEmpty => requests.isEmpty;

  ConnectionsCenterLoaded copyWith({
    List<PatientLinkRequest>? requests,
    String? actingOnId,
    ResolvedRequest? lastResolved,
    bool clearActing = false,
    bool clearResolved = false,
  }) {
    return ConnectionsCenterLoaded(
      requests: requests ?? this.requests,
      actingOnId: clearActing ? null : (actingOnId ?? this.actingOnId),
      lastResolved: clearResolved ? null : (lastResolved ?? this.lastResolved),
    );
  }

  @override
  List<Object?> get props => [
        requests.map((r) => r.id).toList(),
        actingOnId,
        lastResolved,
      ];
}

class ConnectionsCenterError extends ConnectionsCenterState {
  final String message;
  const ConnectionsCenterError(this.message);

  @override
  List<Object?> get props => [message];
}

/// Lightweight tag emitted to the UI right after a respond resolves so
/// the card can show its in-place success animation before being removed.
class ResolvedRequest extends Equatable {
  final String requestId;
  final String doctorName;
  final String resolvedStatus; // 'connected' | 'merged' | 'rejected'
  final bool approved;

  const ResolvedRequest({
    required this.requestId,
    required this.doctorName,
    required this.resolvedStatus,
    required this.approved,
  });

  @override
  List<Object?> get props => [requestId, resolvedStatus, approved];
}

class ConnectionsCenterCubit extends Cubit<ConnectionsCenterState> {
  ConnectionsCenterCubit({PatientLinkRequestsService? service})
      : _service = service ?? PatientLinkRequestsService(),
        super(const ConnectionsCenterLoading());

  final PatientLinkRequestsService _service;

  /// Initial load. Called by the page on mount. Safe to call again to
  /// refresh after the user returns from a "details" deep-dive on the
  /// existing review page (where they may have approved/declined).
  Future<void> load() async {
    try {
      final pending = await _service.fetchPending();
      emit(ConnectionsCenterLoaded(requests: pending));
    } catch (e) {
      emit(ConnectionsCenterError(e.toString()));
    }
  }

  /// Approve or decline the request inline. The UI provides confirmation
  /// + animation around this call. We optimistically remove the row only
  /// AFTER the server confirms, so a transient failure leaves the card
  /// in place for the user to retry.
  Future<void> respond({
    required String requestId,
    required bool approve,
  }) async {
    final current = state;
    if (current is! ConnectionsCenterLoaded) return;

    final target = current.requests.firstWhere(
      (r) => r.id == requestId,
      orElse: () => throw StateError('request $requestId not in list'),
    );

    // Mark this card as in-flight.
    emit(current.copyWith(actingOnId: requestId, clearResolved: true));

    try {
      final status = await _service.respond(
        requestId: requestId,
        approve: approve,
      );

      // Drop the resolved row from the list, surface a `lastResolved`
      // tag so the UI can play the in-place success/decline animation.
      final remaining = current.requests
          .where((r) => r.id != requestId)
          .toList(growable: false);

      emit(ConnectionsCenterLoaded(
        requests: remaining,
        lastResolved: ResolvedRequest(
          requestId: requestId,
          doctorName: target.doctorName,
          resolvedStatus: status,
          approved: approve,
        ),
      ));
    } catch (e) {
      // Keep the card in place; clear in-flight; surface a transient
      // error to the UI via a dedicated state. We don't tear down the
      // whole list for one failed action — that would be hostile.
      emit(current.copyWith(clearActing: true));
      rethrow; // page-level listener catches and shows snackbar
    }
  }

  /// Acknowledge the most-recent resolved tag (so the success animation
  /// only plays once per resolution). Called by the UI after the
  /// animation completes.
  void acknowledgeResolved() {
    final current = state;
    if (current is ConnectionsCenterLoaded && current.lastResolved != null) {
      emit(current.copyWith(clearResolved: true));
    }
  }
}
