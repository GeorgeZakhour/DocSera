import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'modular_report_model.dart';
import 'visit_report_model.dart';
import 'visit_reports_service.dart';

class VisitReportsState {
  final bool loading;
  final List<VisitReport> legacyReports;
  final List<ModularReport> modularReports;

  VisitReportsState({
    required this.loading,
    required this.legacyReports,
    required this.modularReports,
  });

  factory VisitReportsState.initial() =>
      VisitReportsState(loading: false, legacyReports: [], modularReports: []);

  // Backward compat: existing code reads state.reports
  List<VisitReport> get reports => legacyReports;
}

class VisitReportsCubit extends Cubit<VisitReportsState> {
  final VisitReportsService service;

  String? userId;
  String? relativeId;

  VisitReportsCubit({required this.service})
      : super(VisitReportsState.initial()) {
    debugPrint("🟢 [VisitReportsCubit] created");
  }

  Future<void> loadReports() async {
    debugPrint("🔍 [VisitReportsCubit.loadReports] start → "
        "userId=$userId, relativeId=$relativeId");

    emit(VisitReportsState(
      loading: true,
      legacyReports: state.legacyReports,
      modularReports: state.modularReports,
    ));

    try {
      final legacyFuture = service.fetchReports(
        userId: userId,
        relativeId: relativeId,
      );
      final modularFuture = service.fetchModularReports(
        userId: userId,
        relativeId: relativeId,
      );

      final results = await Future.wait([legacyFuture, modularFuture]);

      debugPrint("✅ [VisitReportsCubit.loadReports] fetched "
          "${(results[0] as List).length} legacy + ${(results[1] as List).length} modular");

      emit(VisitReportsState(
        loading: false,
        legacyReports: results[0] as List<VisitReport>,
        modularReports: results[1] as List<ModularReport>,
      ));
    } catch (e) {
      debugPrint("❌ [VisitReportsCubit.loadReports] error: $e");
      emit(VisitReportsState(loading: false, legacyReports: [], modularReports: []));
    }
  }

  void updatePatient({required String? newUserId, required String? newRelativeId}) {
    debugPrint("👤 [VisitReportsCubit.updatePatient] incoming → "
        "newUserId=$newUserId, newRelativeId=$newRelativeId");

    final bool isRelative = newRelativeId != null;

    userId = isRelative ? null : newUserId;
    relativeId = isRelative ? newRelativeId : null;

    debugPrint("👉 [VisitReportsCubit.updatePatient] normalized → "
        "userId=$userId, relativeId=$relativeId, isRelative=$isRelative");

    loadReports();
  }
}
