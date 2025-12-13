import 'package:bloc/bloc.dart';
import 'visit_report_model.dart';
import 'visit_reports_service.dart';

class VisitReportsState {
  final bool loading;
  final List<VisitReport> reports;

  VisitReportsState({required this.loading, required this.reports});

  factory VisitReportsState.initial() =>
      VisitReportsState(loading: false, reports: []);
}

class VisitReportsCubit extends Cubit<VisitReportsState> {
  final VisitReportsService service;

  String? userId;
  String? relativeId;

  VisitReportsCubit({required this.service})
      : super(VisitReportsState.initial()) {
    print("🟢 [VisitReportsCubit] created");
  }

  Future<void> loadReports() async {
    print("🔍 [VisitReportsCubit.loadReports] start → "
        "userId=$userId, relativeId=$relativeId");

    emit(VisitReportsState(loading: true, reports: state.reports));

    try {
      final list = await service.fetchReports(
        userId: userId,
        relativeId: relativeId,
      );

      print("✅ [VisitReportsCubit.loadReports] fetched ${list.length} reports "
          "for userId=$userId, relativeId=$relativeId");

      emit(VisitReportsState(loading: false, reports: list));
    } catch (e) {
      print("❌ [VisitReportsCubit.loadReports] error: $e");
      emit(VisitReportsState(loading: false, reports: []));
    }
  }

  void updatePatient({required String? newUserId, required String? newRelativeId}) {
    print("👤 [VisitReportsCubit.updatePatient] incoming → "
        "newUserId=$newUserId, newRelativeId=$newRelativeId");

    final bool isRelative = newRelativeId != null;

    userId = isRelative ? null : newUserId;
    relativeId = isRelative ? newRelativeId : null;

    print("👉 [VisitReportsCubit.updatePatient] normalized → "
        "userId=$userId, relativeId=$relativeId, isRelative=$isRelative");

    loadReports();
  }
}
