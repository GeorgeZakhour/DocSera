import 'package:bloc/bloc.dart';
import 'package:docsera/screens/home/health/models/health_models.dart';
import 'package:docsera/screens/home/health/services/health_records_service.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HealthState extends Equatable {
  final bool isLoading;
  final List<HealthRecord> records;
  final bool noItemsDeclared;
  final String? errorMessage;

  const HealthState({
    required this.isLoading,
    required this.records,
    required this.noItemsDeclared,
    this.errorMessage,
  });

  factory HealthState.initial() {
    return const HealthState(
      isLoading: false,
      records: [],
      noItemsDeclared: false,
      errorMessage: null,
    );
  }

  HealthState copyWith({
    bool? isLoading,
    List<HealthRecord>? records,
    bool? noItemsDeclared,
    String? errorMessage,
  }) {
    return HealthState(
      isLoading: isLoading ?? this.isLoading,
      records: records ?? this.records,
      noItemsDeclared: noItemsDeclared ?? this.noItemsDeclared,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    isLoading,
    records,
    noItemsDeclared,
    errorMessage,
  ];
}

class HealthCubit extends Cubit<HealthState> {
  final String category;
  final HealthRecordsService service;
  final SupabaseClient _client;

  /// Supports both user and relative records
  String? userId;
  String? relativeId;

  HealthCubit({
    required this.category,
    required this.service,
    required this.userId,
    required this.relativeId,
    SupabaseClient? client,
  })  : _client = client ?? Supabase.instance.client,
        super(HealthState.initial());

  // --------------------------------------------------------------
  // LOAD RECORDS
  // --------------------------------------------------------------
  Future<void> loadRecords() async {
    debugPrint("📥 HealthCubit.loadRecords() START");
    debugPrint("   category=$category");
    debugPrint("   userId=$userId relativeId=$relativeId");

    emit(state.copyWith(isLoading: true));

    try {
      final records = await service.fetchRecords(
        userId: userId,
        relativeId: relativeId,
        category: category,
      );

      debugPrint("📥 loadRecords RESULT count=${records.length}");

      emit(state.copyWith(isLoading: false, records: records));
    } catch (e) {
      debugPrint("❌ loadRecords ERROR: $e");
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }


  // --------------------------------------------------------------
  // SEARCH MASTER LIST
  // --------------------------------------------------------------
  Future<List<HealthMasterItem>> searchMaster(String q) {
    return service.searchMaster(category, q);
  }

  // --------------------------------------------------------------
  // CREATE CUSTOM MASTER ITEM (manual entry)
  // --------------------------------------------------------------
  Future<HealthMasterItem> createCustomMasterItem({
    required String nameEn,
    required String nameAr,
    String? descriptionEn,
    String? descriptionAr,
  }) {
    return service.createCustomMasterItem(
      category: category,
      nameEn: nameEn,
      nameAr: nameAr,
      descriptionEn: descriptionEn,
      descriptionAr: descriptionAr,
    );
  }

  // --------------------------------------------------------------
  // ADD NEW RECORD
  // --------------------------------------------------------------
// --------------------------------------------------------------
// ADD NEW RECORD  (FIXED)
// --------------------------------------------------------------
  Future<void> addRecord({
    required HealthMasterItem master,
    String? severity,
    DateTime? startDate,
    String? notes,
    required bool isArabicNotes,
  }) async {
    emit(state.copyWith(isLoading: true));

    // ------------------------------------------------------------
    // FIX: resolve correct target patient
    // ------------------------------------------------------------
    final bool isRelative = relativeId != null;

    final String? patientIdToSend = isRelative ? null : userId;
    final String? relativeIdToSend = isRelative ? relativeId : null;

    debugPrint("🟩 addRecord() sending:");
    debugPrint("   category=$category");
    debugPrint("   masterId=${master.id}");
    debugPrint("   patientId=$patientIdToSend");
    debugPrint("   relativeId=$relativeIdToSend");

    try {
      await service.addRecord(
        category: category,
        masterId: master.id,
        userId: patientIdToSend,      // FIXED
        relativeId: relativeIdToSend, // FIXED
        severity: severity,
        startDate: startDate,
        notes: notes,
        isArabicNotes: isArabicNotes,
      );

      // ثم نعيد تحميل السجلات
      await loadRecords();

    } catch (e) {
      debugPrint("❌ Error in addRecord: $e");
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
      return;
    }

    emit(state.copyWith(isLoading: false));
  }


  // --------------------------------------------------------------
  // DELETE RECORD
  // --------------------------------------------------------------
  Future<void> deleteRecord(String id) async {
    emit(state.copyWith(isLoading: true));
    await service.deleteRecord(id);
    await loadRecords();
  }

  // --------------------------------------------------------------
  // UPDATE RECORD (optional severity / start_date / notes)
  // --------------------------------------------------------------
  Future<void> updateRecord({
    required String recordId,
    String? severity,
    bool setSeverity = false,
    DateTime? startDate,
    bool setStartDate = false,
    String? notes,
    bool setNotes = false,
    required bool isArabicNotes,
  }) async {
    try {
      await service.updateRecord(
        id: recordId,
        severity: severity,
        setSeverity: setSeverity,
        startDate: startDate,
        setStartDate: setStartDate,
        notes: notes,
        setNotes: setNotes,
        isArabicNotes: isArabicNotes,
      );
      await loadRecords();
    } catch (e) {
      debugPrint("❌ Error in updateRecord: $e");
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  // --------------------------------------------------------------
  // NO ITEMS DECLARED
  // --------------------------------------------------------------
  void setNoItemsDeclared(bool v) {
    emit(state.copyWith(noItemsDeclared: v));
  }

  // --------------------------------------------------------------
  // UPDATE ACTIVE PATIENT (user or relative)
  // --------------------------------------------------------------
  void updatePatient({
    required String? newUserId,
    required String? newRelativeId,
  }) {
    debugPrint("🟦 HealthCubit.updatePatient()");
    debugPrint("   OLD userId=$userId relativeId=$relativeId");
    debugPrint("   NEW userId=$newUserId relativeId=$newRelativeId");

    final changed = newUserId != userId || newRelativeId != relativeId;

    if (!changed) {
      debugPrint("❌ No change detected. NOT reloading records");
    }

    userId = newUserId;
    relativeId = newRelativeId;

    if (changed) {
      debugPrint("🔄 Patient changed → Reloading records...");
      loadRecords();
    } else {
      debugPrint("⭕ Patient DID NOT change → Skipping loadRecords()");
    }
  }



}
