import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:docsera/services/supabase/storage_quota_service.dart';
import 'storage_quota_state.dart';

class StorageQuotaCubit extends Cubit<StorageQuotaState> {
  final StorageQuotaService _service;

  StorageQuotaCubit({StorageQuotaService? service})
      : _service = service ?? StorageQuotaService(),
        super(const StorageQuotaInitial());

  /// Loads current storage usage and emits [StorageQuotaLoaded].
  Future<void> loadStorageUsage() async {
    emit(const StorageQuotaLoading());
    try {
      final quota = await _service.getStorageUsage();
      emit(StorageQuotaLoaded(quota));
    } catch (e) {
      emit(StorageQuotaError(e.toString()));
    }
  }

  /// Checks whether a file of [fileSize] bytes can be uploaded.
  /// Emits [StorageQuotaLoaded] with the updated quota and returns it,
  /// or emits [StorageQuotaError] and returns null on failure.
  Future<StorageQuotaResult?> checkUploadAllowed(int fileSize) async {
    try {
      final result = await _service.checkUploadAllowed(fileSize);
      emit(StorageQuotaLoaded(result));
      return result;
    } catch (e) {
      emit(StorageQuotaError(e.toString()));
      return null;
    }
  }

  /// Marks the warning at [level] (70 or 90) as shown, then refreshes usage.
  Future<void> markWarningShown(int level) async {
    try {
      await _service.markWarningShown(level);
      await loadStorageUsage();
    } catch (e) {
      emit(StorageQuotaError(e.toString()));
    }
  }

  /// Returns the patient's largest documents for the cleanup UI.
  Future<List<Map<String, dynamic>>> getLargestDocuments() async {
    try {
      return await _service.getLargestDocuments();
    } catch (e) {
      emit(StorageQuotaError(e.toString()));
      return [];
    }
  }

  /// Refreshes storage usage after a document has been deleted.
  Future<void> refreshAfterDelete() => loadStorageUsage();
}
